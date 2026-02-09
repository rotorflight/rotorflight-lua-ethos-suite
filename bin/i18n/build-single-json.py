# i18n/build-single-json.py
#!/usr/bin/env python3
import sys, json
from pathlib import Path

# Source root: bin/i18n/json/<locale>.json
JSON_ROOT = Path(__file__).parent / "json"

# Output root: src/rfsuite/i18n/<locale>.json
OUT_DIR = (Path(__file__).parent / ".." / ".." / "src" / "rfsuite" / "i18n").resolve()

def discover_locale_files():
    """Yield tuples (locale, file_path) for every i18n/json/<locale>.json."""
    for fpath in sorted(JSON_ROOT.glob("*.json")):
        locale = fpath.stem
        if locale:
            yield (locale, fpath)

def main(argv=None):
    if not JSON_ROOT.exists():
        print(f"ERROR: source directory not found: {JSON_ROOT}", file=sys.stderr)
        return 1

    # optional: filter by locales if passed (e.g. --only en de)
    import argparse
    ap = argparse.ArgumentParser(description="Build merged per-locale JSON files from i18n/json/**/<locale>.json")
    ap.add_argument("--only", nargs="*", help="Limit to specific locales (e.g. --only en de fr)")
    args = ap.parse_args(argv)

    errors = []

    locales = []
    for locale, fpath in discover_locale_files():
        if args.only and locale not in args.only:
            continue
        try:
            with fpath.open("r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            errors.append(f"{fpath}: {e}")
            continue
        locales.append((locale, data))

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    written = 0
    for locale, data in sorted(locales):
        out_path = OUT_DIR / f"{locale}.json"
        with out_path.open("w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        written += 1
        print(f"✔ Wrote {out_path}")

    if errors:
        print("\nSome files could not be read/parsed:", file=sys.stderr)
        for line in errors:
            print(f"  - {line}", file=sys.stderr)

    if written == 0:
        print("WARNING: No locale files found under", JSON_ROOT, file=sys.stderr)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
