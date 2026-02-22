#!/usr/bin/env python3
import json
import re
import argparse
from collections import OrderedDict
from pathlib import Path

JSON_ROOT = Path(__file__).parent / "json"


def read_json(path: Path) -> OrderedDict:
    raw = path.read_text(encoding="utf-8")
    raw = re.sub(r",\s*([}\]])", r"\1", raw)
    return json.loads(raw, object_pairs_hook=OrderedDict)


def write_json(path: Path, data: OrderedDict) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)


def is_translation_block(node) -> bool:
    return isinstance(node, dict) and "english" in node and "translation" in node


def collect_locale_data(only_locales=None):
    locales = {}
    for fpath in sorted(JSON_ROOT.glob("*.json")):
        locale = fpath.stem
        if only_locales and locale != "en" and locale not in only_locales:
            continue
        try:
            locales[locale] = read_json(fpath)
        except Exception as e:
            print(f"❌ Failed to parse {fpath}: {e}")
    return locales


def get_node_by_path(root, path_parts):
    node = root
    for part in path_parts:
        if not isinstance(node, dict):
            return None
        node = node.get(part)
    return node


def compute_max_length(data, path_parts):
    max_len = 0
    node = get_node_by_path(data, path_parts)
    if is_translation_block(node):
        text = node.get("translation", "")
        if text is None:
            text = ""
        max_len = max(max_len, len(text))
    return max_len


def update_max_lengths(node, data, path_parts):
    if not isinstance(node, dict):
        return
    for key, val in node.items():
        if is_translation_block(val):
            parts = path_parts + [key]
            max_len = compute_max_length(data, parts)
            if max_len > 0:
                val["max_length"] = max_len
        elif isinstance(val, dict):
            update_max_lengths(val, data, path_parts + [key])


def update_max_lengths_all_locales(locales, en_data):
    # Walk master (en) keys and apply en's max_length to every locale file.
    def walk(node, path_parts):
        if not isinstance(node, dict):
            return
        for key, val in node.items():
            if is_translation_block(val):
                parts = path_parts + [key]
                max_len = val.get("max_length")
                if not isinstance(max_len, int) or max_len <= 0:
                    continue
                for _, data in locales.items():
                    tgt = get_node_by_path(data, parts)
                    if is_translation_block(tgt):
                        tgt["max_length"] = max_len
            elif isinstance(val, dict):
                walk(val, path_parts + [key])
    walk(en_data, [])


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description="Update max_length in i18n JSON files.")
    ap.add_argument("--only", nargs="*", help="Limit to specific locales (e.g. --only nl)")
    return ap.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    only_locales = set(args.only or [])

    en_path = JSON_ROOT / "en.json"
    if not en_path.exists():
        print(f"❌ Missing {en_path}")
        return 1

    locales = collect_locale_data(only_locales if only_locales else None)
    en_data = locales.get("en")
    if not isinstance(en_data, dict):
        print("❌ en.json is not an object")
        return 1

    update_max_lengths(en_data, en_data, [])
    update_max_lengths_all_locales(locales, en_data)
    # Write all locales, preserving en as master
    for locale, data in locales.items():
        path = JSON_ROOT / f"{locale}.json"
        write_json(path, data)
    if only_locales:
        target_text = ", ".join(sorted(only_locales))
        print(f"✔ Updated max_length values for en + [{target_text}]")
    else:
        print(f"✔ Updated max_length values in {JSON_ROOT}/*.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
