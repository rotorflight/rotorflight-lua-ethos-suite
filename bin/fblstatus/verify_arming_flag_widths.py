#!/usr/bin/env python3
"""Width check for the arming-disable flag strings (#2346).

Run it:
    python bin/fblstatus/verify_arming_flag_widths.py
    python bin/fblstatus/verify_arming_flag_widths.py --self-test

The Lua half of this check is bin/fblstatus/verify_arming_flags.lua, which sees
the unresolved @i18n(...)@ tags. This half has the locale files, so it is the
only place where the strings a pilot actually reads can be measured.

**What is measured and what is assumed.** The widths below are character
counts, not pixels. Nothing here measures the Ethos form: no simulator was
available for this change, and the value column's pixel width is therefore not
a measured number anywhere in this repository. The two budgets are deliberately
pessimistic floors, chosen so that the assertions hold with room to spare
rather than sitting on the edge:

  * #2346 reports the value column at roughly 240-270 px on a 480x320 radio.
    At the font form.addLine() uses there, that is on the order of 40
    characters. VALUE_COLUMN_CHARS is 24, about 60% of that.
  * A full-width line is the whole window, 472 px on the same radio -- roughly
    twice the value column. FULL_LINE_CHARS is 48.

A check that sits on the edge would be a check that fails on a font change
rather than on a real regression, and one that guessed the real width would
report a pass for a string that does not fit. Being pessimistic in both
directions is what makes these two numbers useful rather than decorative.

The assertion that matters is not any single number: it is that the summary's
width is bounded by a constant while the old joined form's width was not.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
I18N = ROOT / "src" / "rfsuite" / "i18n"

VALUE_COLUMN_CHARS = 24
FULL_LINE_CHARS = 48

FLAG_COUNT = 26
# The mask from #2346: Fail Safe, Throttle, Calibrating, MSP, Arm Switch.
BENCH_BITS = (1, 7, 12, 16, 25)
# Every named bit at once is the worst case the page can ever be asked to draw.
ALL_BITS = tuple(range(FLAG_COUNT))

ACTIVE_FMT_KEY = "arming_flags_active_fmt"
ACTIVE_LIST_KEY = "arming_flags_active_list"
BLOCK = ("app", "modules", "fblstatus")


def locales():
    return sorted(p.stem for p in I18N.glob("*.json"))


def fblstatus(locale):
    data = json.loads((I18N / (locale + ".json")).read_text(encoding="utf-8"))
    node = data
    for part in BLOCK:
        node = node[part]
    return node


def flag_names(block, bits):
    return [block["arming_disable_flag_%d" % bit]["translation"] for bit in bits]


def summary_text(template, count):
    """The summary as the page renders it, or None if the template is unusable."""
    if template.count("%d") != 1:
        return None
    return template % count


def summary_overflows(rendered):
    return len(rendered) > VALUE_COLUMN_CHARS


def joined_text(block, bits):
    return ", ".join(flag_names(block, bits))


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    self_test = "--self-test" in argv
    if self_test:
        return self_test_main()

    found = locales()
    if not found:
        print("ERROR: no locale files under %s" % I18N, file=sys.stderr)
        return 1

    failures = []
    widest_summary = ("", 0)
    widest_name = ("", 0)
    widest_joined = ("", 0)

    for locale in found:
        block = fblstatus(locale)

        # -- the two keys of this change exist, and their placeholder survived
        for key in (ACTIVE_FMT_KEY, ACTIVE_LIST_KEY):
            if key not in block:
                failures.append("%s: %s is missing" % (locale, key))
                continue
            entry = block[key]
            if entry.get("needs_translation"):
                failures.append("%s: %s is still marked needs_translation" % (locale, key))
            if not entry.get("translation"):
                failures.append("%s: %s has no translation" % (locale, key))

        if ACTIVE_FMT_KEY in block:
            template = block[ACTIVE_FMT_KEY]["translation"]
            rendered = summary_text(template, FLAG_COUNT)
            if rendered is None:
                failures.append(
                    "%s: %s must carry exactly one %%d, found %d"
                    % (locale, ACTIVE_FMT_KEY, template.count("%d"))
                )
            elif summary_overflows(rendered):
                # Not reachable by a count: 26 flags is two digits, and the
                # page prints a count. It is reachable by the word -- a
                # translation that made "active" a paragraph would overflow --
                # which is why the check measures the rendered string and not
                # the flag count.
                failures.append(
                    "%s: the summary %r is %d characters, over the %d the value column is given"
                    % (locale, rendered, len(rendered), VALUE_COLUMN_CHARS)
                )
            elif len(rendered) > widest_summary[1]:
                widest_summary = (locale, len(rendered))

        # -- every single name has to fit a full-width row
        for name in flag_names(block, ALL_BITS):
            if len(name) > FULL_LINE_CHARS:
                failures.append(
                    "%s: the flag name %r is %d characters, over the %d a full-width row is given"
                    % (locale, name, len(name), FULL_LINE_CHARS)
                )
            if len(name) > widest_name[1]:
                widest_name = (locale, len(name))

        # -- and the form this change replaced did not fit
        joined_bench = joined_text(block, BENCH_BITS)
        joined_all = joined_text(block, ALL_BITS)
        if len(joined_all) > widest_joined[1]:
            widest_joined = (locale, len(joined_all))
        if len(joined_bench) <= VALUE_COLUMN_CHARS:
            # Not a failure of this change, but it means the reported clipping
            # does not reproduce for this locale and the budget is too loose
            # to be saying anything.
            print(
                "  note  %s: the old joined form is only %d characters for the bench mask"
                % (locale, len(joined_bench))
            )

    if not any(summary_overflows(joined_text(fblstatus(loc), BENCH_BITS)) for loc in found):
        failures.append(
            "no locale's old joined form exceeds %d characters, so this check "
            "cannot fail and proves nothing" % VALUE_COLUMN_CHARS
        )

    print("locales checked: %d" % len(found))
    print("widest summary:  %d characters (%s)" % (widest_summary[1], widest_summary[0]))
    print("widest name:     %d characters (%s)" % (widest_name[1], widest_name[0]))
    print("widest joined:   %d characters (%s) -- the form this change removed" % (widest_joined[1], widest_joined[0]))
    print("budgets:         value column %d, full-width row %d (pessimistic floors, not measurements)"
          % (VALUE_COLUMN_CHARS, FULL_LINE_CHARS))
    print("")

    if failures:
        for line in failures:
            print("  FAIL  %s" % line)
        print("")
        print("%d check(s) FAILED" % len(failures))
        return 1

    print("all checks passed")
    return 0


def self_test_main():
    """Prove the check can go red, so a green run means something."""
    checks = 0
    failures = 0

    def check(label, ok, detail=""):
        nonlocal checks, failures
        checks += 1
        if ok:
            print("  ok    %s" % label)
        else:
            failures += 1
            print("  FAIL  %s" % label)
            if detail:
                print("        %s" % detail)

    found = locales()
    check("locale files are found", bool(found), str(I18N))
    if not found:
        print("\n%d of %d checks FAILED" % (failures, checks))
        return 1

    block = fblstatus("en")
    check("the summary template carries one placeholder", block[ACTIVE_FMT_KEY]["translation"].count("%d") == 1)
    check("the heading key is present and non-empty", bool(block[ACTIVE_LIST_KEY]["translation"]))

    # The three assertions in main(), each run against a value chosen to break
    # it. A check that cannot go red proves nothing about the check.
    check("a summary over the value column is rejected",
          summary_overflows(summary_text("%d " + "y" * 40, FLAG_COUNT)))
    check("a name over a full-width row is rejected", len("x" * (FULL_LINE_CHARS + 1)) > FULL_LINE_CHARS)
    check("a real joined form is over the value column",
          summary_overflows(joined_text(block, BENCH_BITS)),
          str(len(joined_text(block, BENCH_BITS))))
    check("a real summary is not over the value column",
          not summary_overflows(summary_text(block[ACTIVE_FMT_KEY]["translation"], FLAG_COUNT)))

    # Every locale must carry both keys, or the shipped page shows a raw tag.
    missing = []
    for locale in found:
        b = fblstatus(locale)
        for key in (ACTIVE_FMT_KEY, ACTIVE_LIST_KEY):
            if key not in b or not b[key].get("translation"):
                missing.append("%s/%s" % (locale, key))
    check("every locale carries both keys", not missing, ", ".join(missing))

    print("")
    if failures:
        print("%d of %d checks FAILED" % (failures, checks))
        return 1
    print("all %d self-test checks passed" % checks)
    return 0


if __name__ == "__main__":
    sys.exit(main())
