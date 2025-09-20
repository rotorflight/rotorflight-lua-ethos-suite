import os
import json
import re
from collections import OrderedDict

ROOT_DIR = "json"

def read_json(filepath):
    """Load JSON file with support for trailing commas."""
    with open(filepath, "r", encoding="utf-8") as f:
        raw = f.read()
        raw = re.sub(r",\s*([}\]])", r"\1", raw)  # Remove trailing commas
        return json.loads(raw, object_pairs_hook=OrderedDict)

def write_json(filepath, data):
    """Write JSON using pretty formatting."""
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

def extract_key_order(data):
    """Recursively extract key order from a JSON object."""
    if not isinstance(data, dict):
        return None
    order = {"__order": list(data.keys())}
    for key, value in data.items():
        if isinstance(value, dict):
            sub_order = extract_key_order(value)
            if sub_order:
                order[key] = sub_order
    return order

def ensure_needs_translation_false(data):
    """Recursively add 'needs_translation': 'false' to en.json translation blocks if missing."""
    if not isinstance(data, dict):
        return
    for key, val in data.items():
        if isinstance(val, dict):
            if "english" in val and "translation" in val:
                val.setdefault("needs_translation", False)
            else:
                ensure_needs_translation_false(val)

def build_translation(ref, target, order):
    """Rebuild translation preserving structure and key order."""
    output = OrderedDict()
    for key in order.get("__order", []):
        ref_val = ref.get(key)
        tgt_val = target.get(key) if target else None

        if isinstance(ref_val, dict) and "english" in ref_val and "translation" in ref_val:
            if isinstance(tgt_val, dict) and "translation" in tgt_val:
                output[key] = {
                    "english": ref_val["english"],
                    "translation": tgt_val["translation"],
                    "needs_translation": tgt_val.get("needs_translation", False)
                }
            else:
                output[key] = {
                    "english": ref_val["english"],
                    "translation": ref_val["english"],
                    "needs_translation": True
                }
        elif isinstance(ref_val, dict):
            output[key] = build_translation(ref_val, tgt_val or {}, order.get(key, {"__order": []}))
        else:
            output[key] = ref_val
    return output

def get_all_dirs(base):
    """Yield all subdirectories recursively."""
    for root, dirs, files in os.walk(base):
        yield root

def process_dir(path):
    files = [f for f in os.listdir(path) if f.endswith(".json")]
    if "en.json" not in files:
        return

    en_path = os.path.join(path, "en.json")
    try:
        en_data = read_json(en_path)
    except Exception as e:
        print(f"❌ Failed to parse {en_path}: {e}")
        return

    if not isinstance(en_data, dict):
        print(f"⚠ Skipping non-object en.json in {en_path}")
        return

    # Fix en.json if it lacks "needs_translation": "false"
    ensure_needs_translation_false(en_data)
    write_json(en_path, en_data)

    # Extract key order for structure
    key_order = extract_key_order(en_data)

    # Process other language files
    for f in files:
        if f == "en.json":
            continue
        target_path = os.path.join(path, f)
        try:
            if os.path.isfile(target_path):
                target_data = read_json(target_path)
                new_data = build_translation(en_data, target_data, key_order)
                write_json(target_path, new_data)
                print(f"✔ Updated: {target_path}")
        except Exception as e:
            print(f"❌ Failed processing {target_path}: {e}")

# 🔁 Run the translation update
if __name__ == "__main__":
    for dir_path in get_all_dirs(ROOT_DIR):
        process_dir(dir_path)
