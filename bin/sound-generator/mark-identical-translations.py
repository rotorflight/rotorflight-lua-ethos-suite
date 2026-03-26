#!/usr/bin/env python3
import json
import re
from pathlib import Path

JSON_ROOT = Path(__file__).parent / "json"


def read_json(path: Path):
    raw = path.read_text(encoding="utf-8")
    raw = re.sub(r",\s*([}\]])", r"\1", raw)
    return json.loads(raw)


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")


def norm_text(text: str) -> str:
    if text is None:
        return ""
    text = text.lower()
    text = re.sub(r"\s+", "", text)
    text = re.sub(r"[^\w]", "", text, flags=re.UNICODE)
    return text


def mark_identical(entries):
    changed = 0
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        eng = entry.get("english", "")
        tr = entry.get("translation", "")
        if norm_text(eng) == norm_text(tr):
            if entry.get("needs_translation") is not True:
                entry["needs_translation"] = True
                changed += 1
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
        if not isinstance(data, list):
            print(f"⚠ Skipping non-array {path}")
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
