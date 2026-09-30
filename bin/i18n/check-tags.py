#!/usr/bin/env python3
"""
Report @i18n(key)@ tags in src/ whose key is missing from a locale file.

A missing key is not an error at build time: the deploy step leaves the tag
untouched, so the pilot sees the raw "@i18n(...)@" text on the radio. This
check finds those before they ship.

Uses the same tag syntax and key lookup as .vscode/scripts/resolve_i18n_tags.py
(the resolver deploy runs), so the two always agree on what is missing.

Usage:
  python bin/i18n/check-tags.py                 # check against en.json
  python bin/i18n/check-tags.py --lang de       # check against de.json
  python bin/i18n/check-tags.py --json          # machine-readable output

Exit status: 0 when every key resolves, 1 when any is missing.
"""

import argparse
import importlib.util
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RESOLVER = REPO / ".vscode" / "scripts" / "resolve_i18n_tags.py"
SRC_ROOT = REPO / "src"
LOCALE_DIR = SRC_ROOT / "rfsuite" / "i18n"


def load_resolver():
    spec = importlib.util.spec_from_file_location("resolve_i18n_tags", RESOLVER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def find_missing(resolver, translations):
    """Return {key: [(relative path, line), ...]} for tags that do not resolve."""
    missing = {}
    for path in sorted(resolver.iter_source_files(SRC_ROOT)):
        if path.parent == LOCALE_DIR:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            for m in resolver.TAG_RE.finditer(line):
                key = m.group(1).strip()
                if resolver.resolve_key(translations, key) is None:
                    rel = path.relative_to(REPO).as_posix()
                    missing.setdefault(key, []).append((rel, lineno))
    return missing


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    ap.add_argument("--lang", default="en", help="locale file to check against (default: en)")
    ap.add_argument("--json", action="store_true", help="print JSON instead of text")
    args = ap.parse_args()

    locale_path = LOCALE_DIR / f"{args.lang}.json"
    if not locale_path.is_file():
        print(f"locale file not found: {locale_path}", file=sys.stderr)
        return 2

    resolver = load_resolver()
    translations = resolver.load_translations(locale_path)
    missing = find_missing(resolver, translations)

    if args.json:
        print(json.dumps({
            "lang": args.lang,
            "locale_file": locale_path.relative_to(REPO).as_posix(),
            "missing": {k: [{"file": f, "line": n} for f, n in v] for k, v in sorted(missing.items())},
        }, indent=2))
    elif missing:
        print(f"[i18n] {len(missing)} key(s) used in src/ are missing from {locale_path.relative_to(REPO).as_posix()}:")
        for key, uses in sorted(missing.items()):
            for rel, lineno in uses:
                print(f"  {rel}:{lineno}: {key}")
        print("[i18n] Add them to bin/i18n/json/<locale>.json and regenerate src/rfsuite/i18n/ (see AGENTS.md section 7).")
    else:
        print(f"[i18n] OK: every @i18n tag in src/ resolves against {args.lang}.json")

    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
