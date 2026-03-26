#!/usr/bin/env python3
import argparse
import json
import os
import re
import sys
from collections import OrderedDict
from pathlib import Path

TAG_RE = re.compile(r"@i18n\(\s*([^)]+?)\s*\)(?::[A-Za-z_]+\(\))?@")


def read_json(filepath: Path) -> OrderedDict:
    """Load JSON with support for trailing commas, preserving key order."""
    raw = filepath.read_text(encoding="utf-8")
    raw = re.sub(r",\s*([}\]])", r"\1", raw)
    return json.loads(raw, object_pairs_hook=OrderedDict)


def write_json(filepath: Path, data: OrderedDict) -> None:
    with filepath.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def is_translation_block(node) -> bool:
    return isinstance(node, dict) and "english" in node and "translation" in node


def iter_source_files(src_root: Path):
    for path in src_root.rglob("*.lua"):
        if path.is_file():
            yield path


def collect_used_keys(src_root: Path) -> set[str]:
    used = set()
    for path in iter_source_files(src_root):
        try:
            text = path.read_text(encoding="utf-8")
        except Exception:
            text = path.read_text(encoding="utf-8", errors="ignore")
        for match in TAG_RE.finditer(text):
            key = match.group(1).strip()
            if key:
                used.add(key)
    return used


def prune_tree(node, prefix_parts, used_keys):
    """Return (new_node, removed_keys)"""
    if not isinstance(node, dict):
        return node, []

    new_node = OrderedDict()
    removed = []

    for key, value in node.items():
        full_key = ".".join(prefix_parts + [key]) if prefix_parts else key
        if is_translation_block(value):
            if full_key in used_keys:
                new_node[key] = value
            else:
                removed.append(full_key)
        elif isinstance(value, dict):
            pruned_child, child_removed = prune_tree(value, prefix_parts + [key], used_keys)
            if isinstance(pruned_child, dict) and len(pruned_child) == 0:
                removed.extend(child_removed)
            else:
                new_node[key] = pruned_child
                removed.extend(child_removed)
        else:
            new_node[key] = value

    return new_node, removed


def main(argv=None) -> int:
    repo_root = Path(__file__).resolve().parents[2]

    ap = argparse.ArgumentParser(
        description="Detect and optionally remove stale i18n entries from en.json files",
        epilog=(
            "Examples:\n"
            "  python bin/i18n/prune-stale-translations.py\n"
            "  python bin/i18n/prune-stale-translations.py --apply\n"
            "  python bin/i18n/prune-stale-translations.py --extra-keys extras.txt\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--src", default=str(repo_root / "src"), help="Source root to scan for @i18n(...)@ tags")
    ap.add_argument("--json-root", default=str(repo_root / "bin" / "i18n" / "json"), help="Root containing i18n json files")
    ap.add_argument("--apply", action="store_true", help="Apply removals to en.json files")
    ap.add_argument("--extra-keys", help="Optional file with extra i18n keys (one per line)")
    ap.add_argument("--fail-on-stale", action="store_true", help="Exit with code 1 if stale keys are found")
    args = ap.parse_args(argv)

    src_root = Path(args.src)
    json_root = Path(args.json_root)

    if not src_root.exists():
        print(f"ERROR: src root not found: {src_root}", file=sys.stderr)
        return 1
    if not json_root.exists():
        print(f"ERROR: json root not found: {json_root}", file=sys.stderr)
        return 1

    used_keys = collect_used_keys(src_root)

    if args.extra_keys:
        extra_path = Path(args.extra_keys)
        if not extra_path.exists():
            print(f"ERROR: extra keys file not found: {extra_path}", file=sys.stderr)
            return 1
        for line in extra_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                used_keys.add(line)

    en_path = json_root / "en.json"
    if not en_path.exists():
        print(f"WARNING: No en.json found at {en_path}")
        return 0

    total_removed = 0
    any_stale = False

    prefix_parts = []
    try:
        data = read_json(en_path)
    except Exception as e:
        print(f"❌ Failed to parse {en_path}: {e}")
        return 1

    pruned, removed = prune_tree(data, prefix_parts, used_keys)

    if removed:
        any_stale = True
        total_removed += len(removed)
        print(f"\n{en_path}")
        for key in removed:
            print(f"  - {key}")

        if args.apply:
            write_json(en_path, pruned)
            print(f"✔ Pruned {len(removed)} stale entr{'y' if len(removed)==1 else 'ies'}")

    if not any_stale:
        print("No stale en.json entries found.")
    else:
        print(f"\nTotal stale entries: {total_removed}")
        if not args.apply:
            print("Dry run only. Re-run with --apply to remove the entries.")

    if args.fail_on_stale and any_stale:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
