#!/usr/bin/env python3
"""Check that .github/workflows/pr.yml is what the job registry renders.

The workflow used to be maintained by hand, and every pull request that added
a harness job put it in the same place in the file. Two open pull requests
that did the same thing collided on context lines that had nothing to do with
either change, and the resolution cost more than it should have:

* On 2026-09-30 #2414 was squash-merged. Two of the jobs it touched had been
  inserted at the same anchor, and the squash concatenated `dashboard-image-caches`
  and `msp-disconnect-gc` onto a single `runs-on:`/`steps:` block, leaving the
  first with a `name:` and nothing else. A job without `runs-on:` is a schema
  violation, so the workflow file stopped loading: the push run on master at
  82179e97 (run 36765043578) reported `failure` with zero jobs, and the
  pull_request run for #2414 (36765011198) failed the same way. #2416's squash
  then did the same to `field-layout`, so master 8354e793 had two such jobs.

* Resolving the conflict meant repairing a file that had nothing to do with
  the change being reviewed, in three pull requests at once.

`pr.yml` is now rendered from bin/ci/pr_jobs.py, so a pull request adds a job
to the registry instead of editing a shared region of a shared file. This
check is the second half of that: it fails when the committed `pr.yml` and the
registry disagree, which is what stops the two from drifting apart.

    python bin/ci/verify_pr_workflow.py --self-test
    python bin/ci/verify_pr_workflow.py
    python bin/ci/verify_pr_workflow.py --write

Line endings are compared after normalising CRLF to LF on both sides. The blob
in git is LF, `core.autocrlf=true` turns a Windows checkout into CRLF, and
there is no `*.yml` rule in .gitattributes -- so without this the same commit
would fail on a Windows clone and pass on CI.
"""

import argparse
import difflib
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pr_jobs import LUA_JOBS, VERBATIM_JOBS  # noqa: E402

WORKFLOW = os.path.join(".github", "workflows", "pr.yml")

HEADER = """\
name: Create rfsuite-lua-ethos-lite ZIP on PR

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
"""

CHECKOUT = "      - name: Checkout code\n        uses: actions/checkout@v4\n"
INSTALL_LUA = (
    "      - name: Install Lua 5.3\n"
    "        run: sudo apt-get update && sudo apt-get install -y lua5.3\n"
)
SELF_TEST_STEP = "      - name: Prove the check can go red\n"

failures = 0
checks = 0


def check(label, ok, detail=""):
    global failures, checks
    checks += 1
    if ok:
        print("  ok    %s" % label)
    else:
        failures += 1
        print("  FAIL  %s%s" % (label, (" -- " + str(detail)) if detail else ""))


def normalise(text):
    return text.replace("\r\n", "\n")


def render_lua_job(job):
    out = []
    if job.rationale.strip():
        for line in job.rationale.rstrip("\n").split("\n"):
            out.append(("  # " + line).rstrip() + "\n")
    out.append("  %s:\n" % job.id)
    out.append("    name: %s\n" % job.name)
    out.append("    runs-on: ubuntu-latest\n")
    out.append("\n")
    out.append("    steps:\n")
    out.append(CHECKOUT)
    out.append("\n")
    out.append(INSTALL_LUA)
    out.append("\n")
    out.append("      - name: %s\n" % job.step)
    out.append("        run: lua5.3 %s\n" % job.script)
    return "".join(out)


def render():
    parts = [HEADER]
    for job in LUA_JOBS:
        parts.append(render_lua_job(job))
        parts.append("\n")
    for block in VERBATIM_JOBS:
        parts.append(block)
        parts.append("\n")
    text = "".join(parts)
    # every job block is followed by one blank line, including the last, and
    # the file ends on a single newline
    text = text.rstrip("\n") + "\n"
    return text


def committed():
    """The pr.yml this check is about: the working tree, else the committed blob.

    Read as bytes and normalised, never through Python's text mode: text mode
    would translate CRLF on read on Windows and hide exactly the difference
    this check has to survive.
    """
    if os.path.isfile(WORKFLOW):
        with open(WORKFLOW, "rb") as fh:
            return normalise(fh.read().decode("utf-8"))
    try:
        raw = subprocess.run(
            ["git", "cat-file", "-p", "HEAD:" + WORKFLOW.replace("\\", "/")],
            capture_output=True,
            check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None
    return normalise(raw.decode("utf-8"))


def case_jobs_are_ordered_and_unique():
    print("case 1: the registry is a list, and every id is unique")
    ids = [job.id for job in LUA_JOBS]
    check("every LuaJob has an id", all(ids))
    check("no id appears twice", len(ids) == len(set(ids)), ids)
    check(
        "no id collides with a verbatim job",
        not (set(ids) & set(job_ids_of_verbatim())),
    )
    check("the registry is not empty", len(ids) > 0, len(ids))


def job_ids_of_verbatim():
    ids = []
    for block in VERBATIM_JOBS:
        for line in block.split("\n"):
            if line.startswith("  ") and line.rstrip().endswith(":") and not line.startswith("    "):
                candidate = line.strip().rstrip(":")
                if candidate and not candidate.startswith("#"):
                    ids.append(candidate)
    return ids


def case_every_script_exists():
    print("case 2: every job names a harness that is in the tree")
    for job in LUA_JOBS:
        check(
            "%s -> %s" % (job.id, job.script),
            os.path.isfile(job.script),
            "missing",
        )


def job_blocks(text):
    """Split rendered YAML into (job_id, [lines]) at the two-space job keys.

    Structural, not a parse. The repo's Python checks are stdlib-only by
    design -- none of them imports PyYAML and no job installs anything -- and a
    gate that needs a network install is a gate that stops running the day the
    install fails. The shape checked here is the one the generator produces, so
    scanning for it is enough, and the four verbatim blocks are hand-written,
    which is exactly where a wrong indent would hide.
    """
    blocks = []
    current = None
    for line in text.split("\n"):
        match = re.match(r"^  ([a-z0-9][a-z0-9-]*):\s*$", line)
        if match:
            current = (match.group(1), [])
            blocks.append(current)
            continue
        if current is not None:
            current[1].append(line)
    return [(job_id, lines) for job_id, lines in blocks]


def case_render_is_wellformed():
    print("case 3: the rendered file has the shape GitHub can load")
    blocks = job_blocks(render())

    check("every job in the render is in the registry", bool(blocks), len(blocks))
    check(
        "every job id in the render is in the registry",
        {job_id for job_id, _ in blocks}
        == set(job_ids_of_verbatim()) | {j.id for j in LUA_JOBS},
        sorted({job_id for job_id, _ in blocks}),
    )

    # This is the defect that cost master two squashes: a job carrying a name
    # and nothing else. It is a schema violation, so the file does not load at
    # all and the run reports failure with zero jobs.
    without_runner = [
        job_id
        for job_id, lines in blocks
        if not any(line.strip().startswith("runs-on:") for line in lines)
    ]
    check(
        "every job has a runs-on (the #2414/#2416 defect)",
        not without_runner,
        without_runner,
    )

    without_steps = [
        job_id
        for job_id, lines in blocks
        if not any(line.strip().startswith("- name:") for line in lines)
    ]
    check("every job has at least one step", not without_steps, without_steps)


def case_render_is_stable():
    print("case 4: rendering twice gives the same bytes")
    check("render() is deterministic", render() == render())
    check("the render ends in exactly one newline", render().endswith("\n") and not render().endswith("\n\n"))


def case_committed_matches():
    print("case 5: the committed pr.yml is what the registry renders")
    rendered = normalise(render())
    current = committed()
    if current is None:
        check("the committed pr.yml could be read", False, "git cat-file failed")
        return
    if current == rendered:
        check("pr.yml matches the registry", True)
        return
    check("pr.yml matches the registry", False, "diff below")
    for line in difflib.unified_diff(
        current.split("\n"),
        rendered.split("\n"),
        fromfile="committed " + WORKFLOW,
        tofile="rendered from bin/ci/pr_jobs.py",
        lineterm="",
    ):
        print("    " + line)


def self_test():
    """Prove the checks above can go red, by breaking each thing on purpose."""
    print("self-test: each check is shown going red on a sabotaged render")
    ok = True

    # 1. a job without runs-on -- the exact shape master carried
    broken = render().replace(
        "  msp-queue:\n    name: MSP queue after an aborted request\n    runs-on: ubuntu-latest\n",
        "  msp-queue:\n    name: MSP queue after an aborted request\n",
        1,
    )
    blocks = dict(job_blocks(broken))
    reported = not any(
        line.strip().startswith("runs-on:")
        for line in blocks.get("msp-queue", [])
    )
    ok = ok and reported
    print(
        "  %s  a job with a name and no runs-on is reported"
        % ("ok   " if reported else "FAIL ")
    )

    # 2. drift between the registry and the committed file
    rendered = normalise(render())
    current = committed()
    if current is not None:
        drifted = current.replace("runs-on: ubuntu-latest", "runs-on: ubuntu-22.04", 1)
        differs = drifted != rendered
        ok = ok and differs
        print(
            "  %s  an edited pr.yml differs from the render"
            % ("ok   " if differs else "FAIL ")
        )
    else:
        print("  skip  cannot read the committed pr.yml")
        ok = False

    # 3. a registry that names a harness nobody wrote
    import pr_jobs

    original = pr_jobs.LUA_JOBS
    pr_jobs.LUA_JOBS = list(original) + [
        pr_jobs.LuaJob(
            id="not-a-real-job",
            name="Not a real job",
            step="Check nothing",
            script="bin/ci/verify_no_such_harness.lua",
            rationale="A job whose harness does not exist.\n",
        )
    ]
    try:
        missing = [j.id for j in pr_jobs.LUA_JOBS if not os.path.isfile(j.script)]
        ok = ok and "not-a-real-job" in missing
        print(
            "  %s  a job naming a missing harness is reported"
            % ("ok   " if "not-a-real-job" in missing else "FAIL ")
        )
    finally:
        pr_jobs.LUA_JOBS = original

    # 4. a duplicated id
    pr_jobs.LUA_JOBS = original + [original[0]]
    ids = [j.id for j in pr_jobs.LUA_JOBS]
    duplicated = len(ids) != len(set(ids))
    ok = ok and duplicated
    print("  %s  a duplicated id is reported" % ("ok   " if duplicated else "FAIL "))
    pr_jobs.LUA_JOBS = original

    print("self-test: %s" % ("every check went red as it should" if ok else "SOME CHECKS STAYED GREEN"))
    return 0 if ok else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="prove the checks below can go red, then exit",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="regenerate pr.yml from the registry instead of checking it",
    )
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    if args.write:
        with open(WORKFLOW, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(render())
        print("wrote %s from bin/ci/pr_jobs.py" % WORKFLOW)
        return 0

    case_jobs_are_ordered_and_unique()
    case_every_script_exists()
    case_render_is_wellformed()
    case_render_is_stable()
    case_committed_matches()

    print("")
    if failures == 0:
        print("all %d checks passed" % checks)
        return 0
    print("%d of %d checks FAILED" % (failures, checks))
    return 1


if __name__ == "__main__":
    sys.exit(main())
