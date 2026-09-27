#!/usr/bin/env python3
"""Check that every appId the flight controller can broadcast has a decoder.

`tasks/elrs_sensors.lua`'s `parseFrame()` walks a custom-telemetry frame as
repeating `(U16 appId, value)` pairs and calls `return` as soon as it meets an
appId it has no entry for. There is no way to skip such a pair: the value's
byte width is not on the wire, it only exists in the decoder table. So one
unregistered appId silently costs every sensor packed *after* it in that same
frame, which is a hard failure to diagnose from the symptom -- the values just
stop updating.

Nothing about that failure points at the cause, so the invariant has to be
checked instead: the decoder table must cover the firmware's appId set. This
compares `src/rfsuite/lib/elrs_sensor_table.lua` against the `TLM_SENSOR(...)`
list in the flight controller's `src/main/telemetry/crsf.c`, which is where
those appIds are declared.

    python bin/telemetry/verify_sensor_table.py
    python bin/telemetry/verify_sensor_table.py --firmware /path/to/crsf.c
    python bin/telemetry/verify_sensor_table.py --self-test

The firmware file is taken from a pinned `snapshot/4.6.0-*` tag by default so
the comparison does not move under the suite's feet; pass `--firmware` to check
against a local checkout, and `--ref` to pin a different firmware revision.
"""

import argparse
import os
import re
import sys
import urllib.request

# Pinned so a firmware that adds an appId shows up as a deliberate diff here
# rather than as a silent frame-walk abort on someone's radio.
DEFAULT_FIRMWARE_REF = "snapshot/4.6.0-20260208"
RAW_URL = "https://raw.githubusercontent.com/rotorflight/rotorflight-firmware/{ref}/src/main/telemetry/crsf.c"

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TABLE_PATH = os.path.join(REPO_ROOT, "src", "rfsuite", "lib", "elrs_sensor_table.lua")

# TLM_SENSOR(NAME, 0xAPPID, ...) and TLM_SENSOR_FULL(...)
FW_ENTRY = re.compile(r"TLM_SENSOR(?:_FULL)?\(\s*[A-Za-z_]\w*\s*,\s*(0x[0-9A-Fa-f]+)")
# [0xAPPID] = { ... } entries in the suite's table
SUITE_ENTRY = re.compile(r"\[\s*(0x[0-9A-Fa-f]+)\s*\]\s*=\s*\{", re.MULTILINE)


def _canon(appid):
    """Both sides keep the 0x prefix and one case, so the sets can meet."""
    return "0x" + appid.lower()[2:].lstrip("0").rjust(4, "0").upper()


def firmware_ids(text):
    return {_canon(m.group(1)) for m in FW_ENTRY.finditer(text)}


def suite_ids(text):
    return {_canon(m.group(1)) for m in SUITE_ENTRY.finditer(text)}


def read_firmware(ref, path):
    if path:
        with open(path, encoding="utf-8-sig", errors="replace") as fh:
            return fh.read()
    url = RAW_URL.format(ref=ref)
    with urllib.request.urlopen(url) as response:
        return response.read().decode("utf-8-sig", errors="replace")


def read_suite(path=TABLE_PATH):
    with open(path, encoding="utf-8-sig") as fh:
        return fh.read()


def verdict(firmware_text, suite_text):
    """Return (ok, reason) for a firmware listing and a suite table."""
    fw = firmware_ids(firmware_text)
    suite = suite_ids(suite_text)
    if not fw:
        return False, (
            "no TLM_SENSOR(...) appIds found in the firmware file -- the pattern "
            "changed, so this check would pass vacuously"
        )
    if not suite:
        return False, "no [0x....] entries found in the suite's sensor table -- same caveat"

    missing = sorted(fw - suite)
    if missing:
        listed = "\n".join("  %s" % a for a in missing)
        return False, (
            "the flight controller broadcasts %d appId(s) the suite cannot decode, so "
            "parseFrame() aborts the frame walk and every sensor packed after them is lost:\n%s\n\n"
            "Add each one to src/rfsuite/lib/elrs_sensor_table.lua. An appId that is not in "
            "the table cannot be skipped -- its byte width only exists there -- so this is "
            "the only fix." % (len(missing), listed)
        )

    extra = sorted(suite - fw)
    note = ""
    if extra:
        note = (
            "\n\nNote: %d appId(s) are in the suite's table but not in this firmware "
            "revision (%s). Harmless -- an entry the firmware never sends is simply "
            "never reached -- but worth a look if the list is expected to match."
            % (len(extra), ", ".join(extra[:10]))
        )
    return True, (
        "all %d appIds the firmware broadcasts have a decoder%s" % (len(fw), note)
    )


#: The control. Every case states a verdict known without running anything, and
#: the two that must fail are the point: a check that cannot go red proves nothing.
SELF_TEST = (
    ("a complete table passes",
     "TLM_SENSOR(VOLTAGE, 0x1015, 0, 0, U16)\nTLM_SENSOR_FULL(ESCTEMP, 0x1057, ...)\n",
     "[0x1015] = {}\n[0x1057] = {}\n", True),
    ("a gap fails and names the appId",
     "TLM_SENSOR(VOLTAGE, 0x1015, 0, 0, U16)\nTLM_SENSOR(ESCTEMP, 0x1057, 0, 0, U8)\n",
     "[0x1015] = {}\n", False),
    ("a surplus suite entry still passes",
     "TLM_SENSOR(VOLTAGE, 0x1015, 0, 0, U16)\n",
     "[0x1015] = {}\n[0x9999] = {}\n", True),
    ("case is irrelevant in hex matching",
     "TLM_SENSOR(V, 0x1057, 0, 0, U8)\n", "[0x1057] = {}\n", True),
    ("an entry without a table body does not count",
     "TLM_SENSOR(V, 0x1057, 0, 0, U8)\n", "-- [0x1057] is only mentioned here\n", False),
    ("an empty firmware listing fails instead of passing vacuously",
     "nothing to see here\n", "[0x1015] = {}\n", False),
    ("an empty suite table fails instead of passing vacuously",
     "TLM_SENSOR(V, 0x1015, 0, 0, U16)\n", "no entries\n", False),
)


def self_test():
    failures = 0
    for name, fw, suite, expected in SELF_TEST:
        ok, reason = verdict(fw, suite)
        mark = "ok  " if ok == expected else "FAIL"
        if ok != expected:
            failures += 1
        print("  %s  expects %-5s %s" % (mark, "pass" if expected else "fail", name))
        if ok != expected:
            print("        got %s: %s" % ("pass" if ok else "fail", reason.splitlines()[0]))
    if failures:
        print("\n%d self-test case(s) failed -- this check proves nothing." % failures)
        return 1
    print("\n%d case(s), both verdicts reached: the check can pass and can go red."
          % len(SELF_TEST))
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--firmware", help="path to the flight controller's crsf.c")
    ap.add_argument("--ref", default=DEFAULT_FIRMWARE_REF,
                    help="firmware revision to read (default: %(default)s)")
    ap.add_argument("--self-test", action="store_true",
                    help="run the control and exit")
    args = ap.parse_args()

    if args.self_test:
        return self_test()

    try:
        firmware_text = read_firmware(args.ref, args.firmware)
    except OSError as exc:
        print("could not read the firmware file: %s" % exc, file=sys.stderr)
        return 2
    suite_text = read_suite()

    ok, reason = verdict(firmware_text, suite_text)
    print("firmware: %s" % (args.firmware or "%s (ref %s)" % (RAW_URL, args.ref)))
    print("suite   : %s" % os.path.relpath(TABLE_PATH, REPO_ROOT))
    print("%d appIds in the firmware, %d in the suite table"
          % (len(firmware_ids(firmware_text)), len(suite_ids(suite_text))))
    if ok:
        print("OK -- %s" % reason)
        return 0
    print("FAILED -- %s" % reason)
    return 1


if __name__ == "__main__":
    sys.exit(main())
