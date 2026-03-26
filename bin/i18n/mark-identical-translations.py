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


def norm_text(text: str) -> str:
    if text is None:
        return ""
    # Case-insensitive, ignore punctuation and whitespace.
    text = text.lower()
    text = re.sub(r"\s+", "", text)
    text = re.sub(r"[^\w]", "", text, flags=re.UNICODE)
    return text


def mark_identical(node):
    if not isinstance(node, dict):
        return 0
    changed = 0
    for key, val in node.items():
        if is_translation_block(val):
            eng = val.get("english", "")
            tr = val.get("translation", "")
            if norm_text(eng) == norm_text(tr):
                if val.get("needs_translation") is not True:
                    val["needs_translation"] = True
                    changed += 1
        elif isinstance(val, dict):
            changed += mark_identical(val)
    return changed


def main():
    if not JSON_ROOT.exists():
        print(f"❌ Missing {JSON_ROOT}")
        return 1

    total_changed = 0
    for path in sorted(JSON_ROOT.glob("*.json")):
        if path.name == "en.json":
            continue
        try:
            data = read_json(path)
        except Exception as e:
            print(f"❌ Failed to parse {path}: {e}")
            continue
        changed = mark_identical(data)
        if changed:
            write_json(path, data)
            print(f"✔ {path} updated ({changed} marked)")
            total_changed += changed
    print(f"Done. Total marked: {total_changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
