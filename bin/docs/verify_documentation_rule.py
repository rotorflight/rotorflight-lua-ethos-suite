#!/usr/bin/env python3
"""Check the documentation rule on a pull request.

`GEMINI.md` and `.agents/rules/documentation.md` ask that a change a pilot can observe
updates its file under `docs/` in the same pull request, and that a pull request which
needs no documentation change says so in its body. Nothing checked either half, so both
rested on the author remembering at the moment they are least likely to.

What this checks is deliberately narrower than what the rule says, because no static
check can decide what a pilot can observe:

  * a pull request that changes nothing under `src/` is asked nothing at all
  * a pull request that changes `src/` and also `docs/` passes
  * a pull request that changes `src/` and no documentation passes only if its body
    carries the statement the rule already asks for

The statement is a line whose first word is `Documentation`, followed by `:` or `.` and
the reason. Bullets and bold markers are ignored, so

    Documentation: no page -- this only renames a local variable.
    - **Documentation.** No page: the change is not reachable from any menu.

are the same statement. Whether the reason is a good one is the reviewer's call and is
not something a check can answer; that the sentence is there, and that a pull request
therefore cannot silently skip the rule, is.

    python bin/docs/verify_documentation_rule.py --base <sha> --body-file <path>
    python bin/docs/verify_documentation_rule.py --self-test
"""

import argparse
import re
import subprocess
import sys

#: What a change to these paths means for the rule. `src/` is what reaches the radio;
#: everything else -- tooling, CI, the packager, the documentation itself -- is not a
#: change a pilot can observe and is not asked for a page.
OBSERVABLE_PREFIX = "src/"
DOCUMENTATION_PREFIX = "docs/"

#: The statement the rule asks for, as a line of its own. A mention of the word inside a
#: sentence is not a statement: `we will add documentation later` has to fail, or the
#: check passes exactly the pull requests it exists for.
STATEMENT_RE = re.compile(
    r"^\s*(?:[-*+]\s+)?[*_]{0,2}documentation[*_]{0,2}\s*[:.][*_]{0,2}\s*(\S.*)$",
    re.IGNORECASE,
)


def verdict(paths, body):
    """Return (ok, reason) for a set of changed paths and a pull-request body."""
    if not any(p.startswith(OBSERVABLE_PREFIX) for p in paths):
        return True, "nothing under %s changed" % OBSERVABLE_PREFIX
    if any(p.startswith(DOCUMENTATION_PREFIX) for p in paths):
        return True, "the pull request updates %s" % DOCUMENTATION_PREFIX
    for line in (body or "").splitlines():
        m = STATEMENT_RE.match(line)
        if m:
            return True, "no %s change, and the body says why: %s" % (
                DOCUMENTATION_PREFIX, m.group(1).strip())
    return False, (
        "this pull request changes %s and no file under %s.\n"
        "  Update the file of the page that changed -- docs/pages/<page path>.md, mirroring\n"
        "  src/rfsuite/app/pages/ -- or, if the change genuinely needs no documentation,\n"
        "  say so in the pull request body on a line of its own, for example\n"
        "\n"
        "      Documentation: no page -- this only renames a local variable.\n"
        "\n"
        "  The rule is in GEMINI.md under Documentation Maintenance and in\n"
        "  .agents/rules/documentation.md." % (OBSERVABLE_PREFIX, DOCUMENTATION_PREFIX))


#: The control. Every case states a verdict that is known without running anything, and
#: the two that must fail are the point: a check that cannot go red proves nothing about
#: the pull requests it passes.
SELF_TEST = (
    (["src/rfsuite/app/pages/setup/model/page.lua"], "",
     False, "a page changes and nothing is said"),
    (["src/rfsuite/app/pages/setup/model/page.lua", "docs/pages/setup/model.md"], "",
     True, "the page and its documentation change together"),
    (["src/rfsuite/lib/utils.lua"],
     "Summary\n\nDocumentation: no page -- this only renames a local variable.\n",
     True, "the statement is there, as a line of its own"),
    (["src/rfsuite/lib/utils.lua"],
     "- **Documentation.** No page: nothing here is reachable from a menu.\n",
     True, "the statement is there, as a bold bullet"),
    (["src/rfsuite/lib/utils.lua"],
     "This is a refactor and we will add documentation later.\n",
     False, "the word appears inside a sentence, which is not a statement"),
    (["src/rfsuite/lib/utils.lua"], "Documentation:" + "\n",
     False, "a marker with no reason after it is not a statement"),
    (["README.md", "bin/package/build_package.py", ".github/workflows/pr.yml"], "",
     True, "nothing that reaches the radio changed"),
    (["docs/pages/README.md"], "",
     True, "a documentation-only pull request"),
)


def self_test():
    failures = 0
    for paths, body, expected, what in SELF_TEST:
        ok, reason = verdict(paths, body)
        mark = "ok  " if ok == expected else "FAIL"
        if ok != expected:
            failures += 1
        print("  %s  %-9s %s" % (mark, "expects " + ("pass" if expected else "fail"), what))
        if ok != expected:
            print("        got %s: %s" % ("pass" if ok else "fail", reason.splitlines()[0]))
    if failures:
        print("\n%d self-test case(s) failed -- this check proves nothing." % failures)
        return 1
    print("\n%d case(s), both verdicts reached: the check can pass and can go red."
          % len(SELF_TEST))
    return 0


def changed_paths(base, head):
    out = subprocess.run(["git", "diff", "--name-only", base, head],
                         capture_output=True, text=True)
    if out.returncode != 0:
        print("git diff %s %s failed\n%s" % (base, head, out.stderr.strip()))
        sys.exit(2)
    return [p.strip() for p in out.stdout.splitlines() if p.strip()]


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", help="the commit the pull request is measured against")
    ap.add_argument("--head", default="HEAD", help="the commit under test")
    ap.add_argument("--body-file", help="a file holding the pull request body")
    ap.add_argument("--self-test", action="store_true",
                    help="run the control and exit")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    if not args.base:
        ap.error("--base is required unless --self-test is given")

    body = ""
    if args.body_file:
        with open(args.body_file, encoding="utf-8") as fh:
            body = fh.read()

    paths = changed_paths(args.base, args.head)
    ok, reason = verdict(paths, body)
    print("%d file(s) changed between %s and %s" % (len(paths), args.base, args.head))
    if ok:
        print("OK -- %s" % reason)
        return 0
    print("FAILED -- %s" % reason)
    return 1


if __name__ == "__main__":
    sys.exit(main())
