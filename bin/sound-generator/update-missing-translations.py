#!/usr/bin/env python3
import json
import sys
from pathlib import Path

def load_json(path):
    with path.open('r', encoding='utf-8') as f:
        return json.load(f)

def write_json(path, data):
    with path.open('w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print(f"✔ Updated {path}")

def sync_translations(json_dir):
    json_dir = Path(json_dir)
    en_path = json_dir / "en.json"
    if not en_path.exists():
        print(f"Error: {en_path} not found", file=sys.stderr)
        sys.exit(1)

    # Load master English array
    en_data = load_json(en_path)
    # Build a lookup of file→english
    en_map = { entry['file']: entry['english'] for entry in en_data }

    # Process each other language JSON
    for lang_file in sorted(json_dir.glob("*.json")):
        if lang_file.name == "en.json":
            continue

        tgt_data = load_json(lang_file)
        # map existing translations by file
        tgt_map = { entry['file']: entry for entry in tgt_data }

        new_array = []
        for en_entry in en_data:
            path = en_entry['file']
            english = en_entry['english']

            if path in tgt_map:
                kept = tgt_map[path]
                translation = kept.get('translation')
                needs = kept.get('needs_translation', translation is None)
            else:
                translation = None
                needs = True

            new_array.append({
                "file": path,
                "english": english,
                "translation": translation,
                "needs_translation": needs
            })

        write_json(lang_file, new_array)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_missing_translations.py <json-directory>", file=sys.stderr)
        sys.exit(1)
    sync_translations(sys.argv[1])
