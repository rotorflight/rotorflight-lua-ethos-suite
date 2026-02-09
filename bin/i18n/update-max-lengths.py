#!/usr/bin/env python3
import json
import re
from collections import OrderedDict
from pathlib import Path

JSON_ROOT = Path(__file__).parent / "json"


def read_json(path: Path) -> OrderedDict:
    raw = path.read_text(encoding="utf-8")
    raw = re.sub(r",\s*([}\]])", r"\1", raw)
    return json.loads(raw, object_pairs_hook=OrderedDict)


def write_json(path: Path, data: OrderedDict) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def is_translation_block(node) -> bool:
    return isinstance(node, dict) and "english" in node and "translation" in node


def collect_locale_data():
    locales = {}
    for fpath in sorted(JSON_ROOT.glob("*.json")):
        try:
            locales[fpath.stem] = read_json(fpath)
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


def compute_max_length(locales, path_parts):
    max_len = 0
    for _, data in locales.items():
        node = get_node_by_path(data, path_parts)
        if is_translation_block(node):
            text = node.get("translation", "")
            if text is None:
                text = ""
            max_len = max(max_len, len(text))
    return max_len


def update_max_lengths(node, locales, path_parts):
    if not isinstance(node, dict):
        return
    for key, val in node.items():
        if is_translation_block(val):
            parts = path_parts + [key]
            max_len = compute_max_length(locales, parts)
            if max_len > 0:
                val["max_length"] = max_len
        elif isinstance(val, dict):
            update_max_lengths(val, locales, path_parts + [key])


def update_max_lengths_all_locales(locales, en_data):
    # Walk master (en) keys and apply max_length to every locale file.
    def walk(node, path_parts):
        if not isinstance(node, dict):
            return
        for key, val in node.items():
            if is_translation_block(val):
                parts = path_parts + [key]
                max_len = compute_max_length(locales, parts)
                if max_len <= 0:
                    continue
                for _, data in locales.items():
                    tgt = get_node_by_path(data, parts)
                    if is_translation_block(tgt):
                        tgt["max_length"] = max_len
            elif isinstance(val, dict):
                walk(val, path_parts + [key])
    walk(en_data, [])


def main():
    en_path = JSON_ROOT / "en.json"
    if not en_path.exists():
        print(f"❌ Missing {en_path}")
        return 1

    locales = collect_locale_data()
    en_data = locales.get("en")
    if not isinstance(en_data, dict):
        print("❌ en.json is not an object")
        return 1

    update_max_lengths(en_data, locales, [])
    update_max_lengths_all_locales(locales, en_data)
    # Write all locales, preserving en as master
    for locale, data in locales.items():
        path = JSON_ROOT / f"{locale}.json"
        write_json(path, data)
    print(f"✔ Updated max_length values in {JSON_ROOT}/*.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
