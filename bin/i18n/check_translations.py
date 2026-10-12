#!/usr/bin/env python3
"""Report the strings a locale build cannot translate.

AGENTS.md asks for i18n on every string. Nothing could see a breach of it. A hardcoded
English label compiles under `luac`, leaves no `@i18n(...)@` marker for the packager to
resolve, produces no warning from `.vscode/scripts/resolve_i18n_tags.py`, and draws
perfectly on the radio -- in English, in every locale. The same is true of a translated
call whose key is assembled at runtime: the precompiler cannot follow it, so it rewrites
nothing and the English fallback ships everywhere.

Two classes, and they are treated differently on purpose.

  assembled key   A call to `t`, `tr` or `i18n.t` whose key is built rather than written:
                  `t("app.onconnect." .. name)`, `tr(prefix .. key)`,
                  `state.i18n.t(entry.key)`. Every substitution in
                  `.vscode/scripts/resolve_i18n_tags.py` needs the key to be a complete
                  quoted literal, so an assembled one is never resolved.

  untranslated    A literal in a place a pilot reads it -- a `label`, `title`, `message`
                  or one of the other text fields of a table, or the label argument of a
                  `Controls.append*` helper -- that never reaches the translator.

Both are REPORTED rather than refused, and each is held at a baseline below: the check
fails when a number grows, not because it is not zero. A check that started red on the
tree it was written for would only teach everybody to ignore it.

The Ethos tree carries no assembled key today (measured 2026-10-11 on master b585088b:
0 hits), so the baseline is 0. Any assembled key is a finding.

The report is the useful half. It groups by literal and sorts by how often each occurs,
because the work is concentrated: a handful of literals account for a third of the total,
and translating those clears far more than walking the files would.

Names are not words. `BLHeli_S` and `CRSF` are the same string in every language, so they
live in `bin/i18n/allowed_untranslated.txt` and are never reported. Adding a line there is
a decision that a string is a name; a word that merely appears often is not one.

    python bin/i18n/check_translations.py             # report, and the ratchet
    python bin/i18n/check_translations.py --report    # report only, never fails
    python bin/i18n/check_translations.py --self-test # the control
"""

import argparse
import collections
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

SOURCE_ROOT = os.path.join("src", "rfsuite")

#: The translation files are the one place an untranslated-looking literal is the point.
EXEMPT_PREFIXES = ("src/rfsuite/i18n/",)

ALLOWLIST_PATH = os.path.join("bin", "i18n", "allowed_untranslated.txt")

#: What the tree carried when this check was written, measured on 0.1.7 at `3a5e2480`
#: with the allow-list beside this file. These are measurements with a date on them, not
#: targets: lower one whenever a pull request clears some, and never raise one. The check
#: fails when a count goes above its baseline, so neither number can grow unnoticed while
#: it stays possible to merge work that does not touch them.
#:
#: A count is a coarse instrument and this is worth knowing: it cannot see one literal
#: replaced by another. It is the honest thing to hold all the same, because the
#: alternative -- a recorded set of every literal in the tree -- is a file nobody would
#: keep true.
BASELINE_UNTRANSLATED = 71  # measured on the Ethos tree, 2026-10-11 (b585088b)
BASELINE_ASSEMBLED = 0

#: The table fields that carry text a pilot reads. `label` and `title` are most of it;
#: `message` is a dialog body; the rest are rarer and cost nothing to look at.
TEXT_FIELDS = ("label", "title", "message", "text", "header", "subtitle",
               "placeholder", "caption", "prompt", "hint", "tooltip")

FIELD_RE = re.compile(
    r'(?<![\w.])(' + "|".join(TEXT_FIELDS) + r')\s*=\s*(["\'])(.*?)\2')

#: A form row's label is the fifth positional argument of every `Controls.append*` helper
#: (`children, x, y, w, labelText, ...` -- see `src/rfsuite/ui/controls.lua`), so it has
#: no field name to key on and the pattern above cannot reach it.
CONTROL_LABEL_RE = re.compile(
    r'\bControls\.append(?:SectionHeader|StaticSectionHeader|RadioSwitch|NumberField'
    r'|ComboSelect|TextField)\(\s*[^,]+,[^,]+,[^,]+,[^,]+,\s*(["\'])(.*?)\1')

#: The three call shapes whose key the precompiler resolves without an `i18n` argument.
#: `(?<![\w.])` on the first two is what keeps `pageT(`, `Common.pageT(` and `x.i18n.t(`
#: out of them: a word boundary matches between a dot and a letter and would fire on all
#: three.
KEY_CALLS = (
    re.compile(r"(?<![\w.])t\s*\("),
    re.compile(r"(?<![\w.])tr\s*\("),
    re.compile(r"(?<![\w.])(?:[A-Za-z0-9_]+\.)?i18n\.t\s*\("),
)

#: A first argument that is a bare name is a wrapper's own parameter -- `local function
#: tr(key, fallback)`, `if t then return t(obj, key, fallback) end`, `i18n.t(fullKey)`.
#: The precompiler rewrites such a wrapper's CALL SITES, so its body never runs in a
#: packaged build and the parameter is not a lost key. Every non-literal key in these
#: shapes in the tree today is of that form, which is why the rule refuses only a key
#: that is assembled.
BARE_NAME_RE = re.compile(r"^[A-Za-z_]\w*$")

#: An `i18n` argument means the call belongs to the other family of shapes, which take
#: the key as their second argument and are not what this rule reads.
I18N_ARG_RE = re.compile(r"(?:[A-Za-z0-9_.]+\.)?i18n|nil")


def strip_comment(line):
    """The line up to its first `--` that is not inside a short string."""
    i, n, quote = 0, len(line), None
    while i < n:
        c = line[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = None
        elif c in "\"'":
            quote = c
        elif c == "-" and i + 1 < n and line[i + 1] == "-":
            return line[:i]
        i += 1
    return line


def reads_as_prose(text):
    """Whether a literal is text a pilot reads, rather than an identifier that looks like it.

    Every clause is a class that occurs in this tree: MSP command names (`MSP_SET_NAME`)
    used as a debug label, a translation key passed as its own fallback
    (`app.pages.x.title`), a duration or a unit (`600s`), a format specifier, a card path,
    and the resolved marker the packager writes back into a source file.
    """
    text = text.strip()
    if len(text) < 2:
        return False
    if not re.search(r"[A-Za-z]{2}", text):
        return False
    if re.fullmatch(r"[A-Z0-9_]+", text):
        return False
    if re.fullmatch(r"[a-z0-9_]+(?:\.[a-z0-9_]+)+", text):
        return False
    if text.startswith("/") or text.startswith("@i18n("):
        return False
    if re.fullmatch(r"[%\-+ .0-9]*[dsfxq]", text):
        return False
    return True


def first_argument(text, open_paren):
    """The source of the first argument of the call whose `(` sits at `open_paren`.

    None where the parenthesis does not close on this line: a call wrapped after its own
    opening bracket is not something a single line can classify, and guessing is how a
    rule starts refusing correct code.
    """
    depth = 0
    start = open_paren + 1
    for i in range(open_paren, len(text)):
        c = text[i]
        if c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                return text[start:i]
        elif c == "," and depth == 1:
            return text[start:i]
    return None


def scan_text(path, text, allowed):
    """(untranslated, assembled) hits for one source file.

    Each hit is (path, line number, literal or source line).
    """
    untranslated = []
    assembled = []
    for number, line in enumerate(text.split("\n"), 1):
        code = strip_comment(line)

        for match in FIELD_RE.finditer(code):
            literal = match.group(3)
            if literal.strip() in allowed:
                continue
            if reads_as_prose(literal):
                untranslated.append((path, number, literal))
        for match in CONTROL_LABEL_RE.finditer(code):
            literal = match.group(2)
            if literal.strip() in allowed:
                continue
            if reads_as_prose(literal):
                untranslated.append((path, number, literal))

        # Blank what is INSIDE every quoted span, so a key that is a complete literal
        # collapses to `""` and a key that merely BEGINS with one keeps what follows it.
        naked = re.sub(r'"[^"]*"', '""', code)
        naked = re.sub(r"'[^']*'", "''", naked)
        for pattern in KEY_CALLS:
            found = False
            for match in pattern.finditer(naked):
                argument = first_argument(naked, match.end() - 1)
                if argument is None:
                    continue
                argument = argument.strip()
                if argument in ('""', "''") or BARE_NAME_RE.match(argument):
                    continue
                if I18N_ARG_RE.fullmatch(argument):
                    continue
                assembled.append((path, number, line.strip()))
                found = True
                break
            if found:
                break
    return untranslated, assembled


def read_allowlist(root):
    path = os.path.join(root, ALLOWLIST_PATH)
    allowed = set()
    if not os.path.isfile(path):
        return allowed
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#"):
                allowed.add(line)
    return allowed


def scan_tree(root, allowed):
    untranslated, assembled, files = [], [], 0
    for base, _dirs, names in os.walk(os.path.join(root, SOURCE_ROOT)):
        for name in sorted(names):
            if not name.endswith(".lua"):
                continue
            full = os.path.join(base, name)
            rel = os.path.relpath(full, root).replace("\\", "/")
            if rel.startswith(EXEMPT_PREFIXES):
                continue
            with open(full, encoding="utf-8", errors="replace") as handle:
                text = handle.read()
            files += 1
            one, two = scan_text(rel, text, allowed)
            untranslated += one
            assembled += two
    return untranslated, assembled, files


def format_report(untranslated, assembled, files, allowed, limit=25):
    lines = []
    lines.append("%d source file(s) read, %d allow-list entry/entries applied"
                 % (files, len(allowed)))
    lines.append("")

    lines.append("Assembled translation keys: %d (baseline %d)"
                 % (len(assembled), BASELINE_ASSEMBLED))
    for path, number, source in assembled:
        lines.append("  %s:%d" % (path, number))
        lines.append("      %s" % source[:110])
    lines.append("")

    by_literal = collections.Counter(literal for _p, _n, literal in untranslated)
    lines.append("Untranslated strings: %d (baseline %d), in %d distinct literal(s)"
                 % (len(untranslated), BASELINE_UNTRANSLATED, len(by_literal)))
    if by_literal:
        top = by_literal.most_common(limit)
        covered = sum(count for _literal, count in top)
        lines.append("  the %d most frequent account for %d of them (%d%%):"
                     % (len(top), covered, covered * 100 // len(untranslated)))
        for literal, count in top:
            where = sorted({p for p, _n, value in untranslated if value == literal})
            first = where[0] + (" and %d more file(s)" % (len(where) - 1)
                                if len(where) > 1 else "")
            lines.append("  %5d  %-34s %s" % (count, '"%s"' % literal[:32], first))
    return "\n".join(lines)


#: The control. Each case is a source fragment whose verdict is known without running
#: anything, and the ones that must produce NOTHING are the point: a rule that reports
#: everything looks exactly like a rule that works, until somebody reads the list.
SELF_TEST = (
    ('local o = { { value = 1, label = "Basic" }, { value = 2, label = "Advanced" } }',
     2, 0, "two option labels the translator never sees"),
    ('return { title = "Help", message = "No help available" }',
     2, 0, "a dialog title and body"),
    ('Controls.appendStaticSectionHeader(children, x, y, w, "Rotor Speed")',
     1, 0, "the label argument of an append helper"),
    ('local s = { label = t(i18n, "esc_basic", "Basic") }',
     0, 0, "a translated call on the right-hand side"),
    ('local r = { labelKey = "esc_basic", labelFallback = "Basic" }',
     0, 0, "the table route the precompiler resolves in place"),
    ('local c = { label = "MSP_SET_NAME" }',
     0, 0, "a command name used as a debug label"),
    ('local k = { label = "app.pages.x.title" }',
     0, 0, "a translation key passed as its own fallback"),
    ('local u = { label = "600s" }',
     0, 0, "a duration"),
    ('local m = { title = "@i18n(app.pages.x.title)@" }',
     0, 0, "a marker the packager has already written"),
    ('local n = { escLabel = "Hobbywing" }',
     0, 0, "a longer field name that merely ends in one of ours"),
    ('-- label = "In a comment"',
     0, 0, "a comment"),
    ('Controls.appendComboSelect(children, x, y, w, targetLabel, opts, v, cb)',
     0, 0, "a label argument that is not a literal"),
    ('local step = t("app.onconnect." .. name)',
     0, 1, "a key that begins with a literal and continues"),
    ('local also = tr(prefix .. key, "Fallback")',
     0, 1, "a key assembled from two names"),
    ('local deep = state.i18n.t(entry.key)',
     0, 1, "a key read out of a table"),
    ('local idx = t(parts[1], "Fallback")',
     0, 1, "a key read out of an array"),
    ('local made = tr(buildKey(name))',
     0, 1, "a key returned by a call"),
    ('local fine = t("app.actions.save", "Save")',
     0, 0, "a complete literal key, which is what the precompiler resolves"),
    ('local ok2 = (t and t("widgets.dashboard.rpm")) or "RPM"',
     0, 0, "the widget shape, with a literal key"),
    ('local ok3 = s.i18n and s.i18n.t and s.i18n.t("widgets.dashboard.volt") or "V"',
     0, 0, "the guarded widget shape, with a literal key"),
    ('local wrap = tr(key, fallback)',
     0, 0, "a wrapper handing its own parameter on"),
    ('local pass = state.i18n.t(fullKey)',
     0, 0, "the same, one call shape over"),
    ('local named = { label = "BLHeli_S" }',
     0, 0, "a name on the allow-list"),
)


def self_test():
    allowed = read_allowlist(ROOT) or {"BLHeli_S"}
    failures = 0
    for source, want_untranslated, want_assembled, what in SELF_TEST:
        untranslated, assembled = scan_text("self-test.lua", source, allowed)
        ok = (len(untranslated) == want_untranslated
              and len(assembled) == want_assembled)
        if not ok:
            failures += 1
        print("  %s  expects %d/%d  %s"
              % ("ok  " if ok else "FAIL", want_untranslated, want_assembled, what))
        if not ok:
            print("        got %d untranslated, %d assembled"
                  % (len(untranslated), len(assembled)))
    reported = sum(case[1] + case[2] for case in SELF_TEST)
    quiet = sum(1 for case in SELF_TEST if case[1] == 0 and case[2] == 0)
    if failures:
        print("\n%d self-test case(s) failed -- this check proves nothing." % failures)
        return 1
    print("\n%d case(s): %d hit(s) found across %d of them, and %d cases that must stay\n"
          "silent did. The check can find something and can keep quiet."
          % (len(SELF_TEST), reported, len(SELF_TEST) - quiet, quiet))
    return 0


def write_step_summary(report):
    path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not path:
        return
    with open(path, "a", encoding="utf-8") as handle:
        handle.write("## Translation coverage\n\n```\n%s\n```\n" % report)


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=ROOT, help="the repository to read")
    parser.add_argument("--report", action="store_true",
                        help="print the report and always exit 0")
    parser.add_argument("--limit", type=int, default=25,
                        help="how many distinct literals the report names")
    parser.add_argument("--self-test", action="store_true",
                        help="run the control and exit")
    args = parser.parse_args()

    if args.self_test:
        return self_test()

    allowed = read_allowlist(args.root)
    untranslated, assembled, files = scan_tree(args.root, allowed)
    if not files:
        print("no source file found under %s -- wrong --root?" % SOURCE_ROOT)
        return 2

    report = format_report(untranslated, assembled, files, allowed, args.limit)
    print(report)
    write_step_summary(report)
    print("")

    if args.report:
        return 0

    problems = []
    if len(assembled) > BASELINE_ASSEMBLED:
        problems.append(
            "%d assembled translation key(s), against a baseline of %d. The precompiler\n"
            "  resolves a key only where it is a complete quoted literal, so an assembled\n"
            "  one ships the English fallback in every locale. Write the key out, or pass\n"
            "  it through the labelKey/labelFallback pair, which the precompiler resolves\n"
            "  in the table."
            % (len(assembled), BASELINE_ASSEMBLED))
    if len(untranslated) > BASELINE_UNTRANSLATED:
        problems.append(
            "%d untranslated strings, against a baseline of %d. This pull request adds\n"
            "  %d. Route them through pageText(i18n, \"key\", \"Fallback\") or the\n"
            "  labelKey/labelFallback pair -- or, where the string is a name rather than\n"
            "  a word, add it to %s."
            % (len(untranslated), BASELINE_UNTRANSLATED,
               len(untranslated) - BASELINE_UNTRANSLATED, ALLOWLIST_PATH))
    if problems:
        print("FAILED")
        for problem in problems:
            print("  " + problem)
        return 1

    won = ((BASELINE_UNTRANSLATED - len(untranslated))
           + (BASELINE_ASSEMBLED - len(assembled)))
    if won > 0:
        print("OK -- %d fewer than the baselines (%d untranslated, %d assembled). Lower\n"
              "  BASELINE_UNTRANSLATED to %d and BASELINE_ASSEMBLED to %d in this file, so\n"
              "  the ground that was won is held."
              % (won, len(untranslated), len(assembled),
                 len(untranslated), len(assembled)))
    else:
        print("OK -- neither count has grown past its baseline.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
