#!/usr/bin/env python3
"""The CI harness jobs, read from one metadata file per harness (issue #2585).

Every harness script that runs in CI has a `<stem>.ci.json` file next to it:

    bin/telemetry_slot_budget/verify_telemetry_slot_budget.ci.json
    bin/telemetry_slot_budget/verify_telemetry_slot_budget.lua

A pull request that adds a harness adds those two files in the harness's own
directory and nothing else. The job list is no longer one shared file that
every such pull request edits in the same place.

A harness that is not a CI job has no `.ci.json`, and is not picked up. The
file holds:

    id         unique, lower-case, used in the job's identity
    name       the job's display name, as shown in the Actions UI
    step       the text of the step that runs the harness
    script     the harness path, relative to the repository root; it must be
               `<directory>/<stem>.lua` for the `<stem>.ci.json` it sits in
    rationale  why the harness exists, one paragraph or more

Commands:

    python bin/ci/harnesses.py --self-test      prove the reader can go red
    python bin/ci/harnesses.py                  print the jobs as JSON
    python bin/ci/harnesses.py --github-output  write the job matrix to $GITHUB_OUTPUT
"""

import glob
import json
import os
import re
import shutil
import sys
import tempfile
from collections import namedtuple

Harness = namedtuple("Harness", "id name step script rationale")

FIELDS = ("id", "name", "step", "script", "rationale")
ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9-]*$")


class HarnessError(Exception):
    pass


def _text(path, data, key):
    value = data.get(key)
    if not isinstance(value, str):
        raise HarnessError("%s: %r must be a string" % (path, key))
    # The rationale may be empty: some harnesses have none written down yet.
    if key != "rationale" and not value.strip():
        raise HarnessError("%s: %r must not be empty" % (path, key))
    if key != "rationale" and "\n" in value:
        raise HarnessError("%s: %r must be one line" % (path, key))
    return value.strip("\n") if key == "rationale" else value


def load_one(path, root):
    """Parse and check one `<stem>.ci.json`. Returns a Harness or raises HarnessError."""
    rel = os.path.relpath(path, root).replace("\\", "/")
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError) as err:
        raise HarnessError("%s: not readable JSON (%s)" % (rel, err))
    if not isinstance(data, dict):
        raise HarnessError("%s: must be a JSON object" % rel)

    missing = [key for key in FIELDS if key not in data]
    if missing:
        raise HarnessError("%s: missing %s" % (rel, ", ".join(missing)))
    extra = sorted(set(data) - set(FIELDS))
    if extra:
        raise HarnessError("%s: unknown keys %s" % (rel, ", ".join(extra)))

    job_id = _text(rel, data, "id")
    if not ID_PATTERN.match(job_id):
        raise HarnessError("%s: id %r must be lower-case letters, digits and dashes" % (rel, job_id))
    name = _text(rel, data, "name")
    step = _text(rel, data, "step")
    rationale = _text(rel, data, "rationale")

    script = _text(rel, data, "script").replace("\\", "/")
    directory = os.path.dirname(rel)
    stem = os.path.basename(rel)[: -len(".ci.json")]
    expected = "%s/%s.lua" % (directory, stem)
    if script != expected:
        raise HarnessError("%s: script must be %s, got %s" % (rel, expected, script))
    if not os.path.isfile(os.path.join(root, script)):
        raise HarnessError("%s: script %s does not exist" % (rel, script))

    return Harness(job_id, name, step, script, rationale)


def discover(root):
    """Every CI harness under bin/, sorted by path. Raises HarnessError on the first bad file."""
    paths = sorted(glob.glob(os.path.join(root, "bin", "*", "*.ci.json")))
    jobs = []
    seen = {}
    for path in paths:
        job = load_one(path, root)
        if job.id in seen:
            raise HarnessError("id %r is used twice: %s and %s" % (
                job.id, seen[job.id], os.path.relpath(path, root).replace("\\", "/")))
        seen[job.id] = os.path.relpath(path, root).replace("\\", "/")
        jobs.append(job)
    return jobs


def matrix_for(jobs):
    """The strategy.matrix value for the harness job.

    A strategy.matrix is an object. The jobs go under "include": a bare list is
    refused by the workflow, and then the harness job never starts (run 39061812227).
    """
    return {"include": [
        {"id": j.id, "name": j.name, "step": j.step, "script": j.script} for j in jobs
    ]}


def _write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


_VALID = {
    "id": "sample-job",
    "name": "A sample job",
    "step": "Check the sample",
    "script": "bin/sample/verify_sample.lua",
    "rationale": "A sample harness for the self-test.",
}


def self_test():
    """Build a scratch tree and check that the reader accepts a good one and refuses each bad one."""
    failures = []

    def expect(label, root, ok):
        try:
            discover(root)
            accepted = True
        except HarnessError:
            accepted = False
        if accepted != ok:
            failures.append(label)
        print("  %s  %s" % ("ok  " if accepted == ok else "FAIL", label))

    def tree(metadata, make_script=True):
        root = tempfile.mkdtemp(prefix="harness-selftest-")
        if make_script:
            script = os.path.join(root, "bin", "sample", "verify_sample.lua")
            os.makedirs(os.path.dirname(script), exist_ok=True)
            with open(script, "w", encoding="utf-8") as f:
                f.write("-- sample\n")
        meta = os.path.join(root, "bin", "sample", "verify_sample.ci.json")
        if isinstance(metadata, str):
            os.makedirs(os.path.dirname(meta), exist_ok=True)
            with open(meta, "w", encoding="utf-8") as f:
                f.write(metadata)
        elif metadata is not None:
            _write(meta, metadata)
        return root

    roots = []

    def check(label, metadata, ok, make_script=True):
        root = tree(metadata, make_script)
        roots.append(root)
        expect(label, root, ok)

    check("a valid harness is accepted", dict(_VALID), True)
    check("no harness at all is accepted (an empty register, not an error)", None, True, make_script=False)
    check("a missing field is refused", {k: v for k, v in _VALID.items() if k != "step"}, False)
    check("an unknown field is refused", dict(_VALID, extra="x"), False)
    check("broken JSON is refused", "{ not json", False)
    check("an empty name is refused", dict(_VALID, name="  "), False)
    check("a multi-line step is refused", dict(_VALID, step="a\nb"), False)
    check("an id with capitals is refused", dict(_VALID, id="Sample"), False)
    check("a script that is not the file's own stem is refused", dict(_VALID, script="bin/sample/other.lua"), False)
    check("a script that does not exist is refused", dict(_VALID), False, make_script=False)

    dup = tempfile.mkdtemp(prefix="harness-selftest-")
    roots.append(dup)
    os.makedirs(os.path.join(dup, "bin", "a"))
    os.makedirs(os.path.join(dup, "bin", "b"))
    for d, stem in (("a", "verify_a"), ("b", "verify_b")):
        with open(os.path.join(dup, "bin", d, stem + ".lua"), "w", encoding="utf-8") as f:
            f.write("-- x\n")
        _write(os.path.join(dup, "bin", d, stem + ".ci.json"), dict(_VALID, script="bin/%s/%s.lua" % (d, stem)))
    expect("two harnesses with the same id are refused", dup, False)

    # The matrix the workflow gets must be an object with the jobs under "include".
    good_root = tree(dict(_VALID))
    roots.append(good_root)
    matrix = matrix_for(discover(good_root))
    shaped = (isinstance(matrix, dict) and list(matrix) == ["include"]
              and len(matrix["include"]) == 1
              and matrix["include"][0]["script"] == _VALID["script"])
    if not shaped:
        failures.append("the matrix is an object with the jobs under include")
    print("  %s  the matrix is an object with the jobs under include" % ("ok  " if shaped else "FAIL"))

    for root in roots:
        shutil.rmtree(root, ignore_errors=True)

    if failures:
        print("FAILED: %s" % ", ".join(failures))
        return 1
    print("ALL CHECKS PASSED")
    return 0


def main(argv):
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    if "--self-test" in argv:
        return self_test()
    try:
        jobs = discover(root)
    except HarnessError as err:
        print("harness metadata: %s" % err, file=sys.stderr)
        return 1
    if not jobs:
        print("harness metadata: no bin/*/*.ci.json found", file=sys.stderr)
        return 1
    matrix = [{"id": j.id, "name": j.name, "step": j.step, "script": j.script} for j in jobs]
    if "--github-output" in argv:
        out = os.environ.get("GITHUB_OUTPUT")
        line = "matrix=%s\n" % json.dumps(matrix_for(jobs), separators=(",", ":"))
        if out:
            with open(out, "a", encoding="utf-8") as f:
                f.write(line)
        else:
            sys.stdout.write(line)
        print("%d harness jobs" % len(matrix))
        return 0
    print(json.dumps(matrix, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
