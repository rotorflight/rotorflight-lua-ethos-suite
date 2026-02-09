import json
import re
from collections import OrderedDict
from pathlib import Path

ROOT_DIR = Path(__file__).parent / "json"

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
                # Preserve existing key order from target to avoid noisy diffs.
                keys = list(tgt_val.keys())
                if not keys:
                    keys = ["english", "translation", "needs_translation"]
                entry = OrderedDict()
                for k in keys:
                    if k == "english":
                        entry[k] = ref_val["english"]
                    elif k == "translation":
                        entry[k] = tgt_val["translation"]
                    elif k == "needs_translation":
                        entry[k] = tgt_val.get("needs_translation", False)
                    else:
                        entry[k] = tgt_val.get(k)
                # Ensure required keys exist
                entry.setdefault("english", ref_val["english"])
                entry.setdefault("translation", tgt_val["translation"])
                entry.setdefault("needs_translation", tgt_val.get("needs_translation", False))
                output[key] = entry
            else:
                output[key] = OrderedDict({
                    "english": ref_val["english"],
                    "translation": ref_val["english"],
                    "needs_translation": True
                })
        elif isinstance(ref_val, dict):
            output[key] = build_translation(ref_val, tgt_val or {}, order.get(key, {"__order": []}))
        else:
            output[key] = ref_val
    return output

def process_root(path: Path):
    en_path = path / "en.json"
    if not en_path.exists():
        print(f"❌ Missing {en_path}")
        return
    try:
        en_data = read_json(str(en_path))
    except Exception as e:
        print(f"❌ Failed to parse {en_path}: {e}")
        return

    if not isinstance(en_data, dict):
        print(f"⚠ Skipping non-object en.json in {en_path}")
        return

    # Fix en.json if it lacks "needs_translation": "false"
    ensure_needs_translation_false(en_data)
    write_json(str(en_path), en_data)

    # Extract key order for structure
    key_order = extract_key_order(en_data)

    # Process other language files
    for target_path in sorted(path.glob("*.json")):
        if target_path.name == "en.json":
            continue
        try:
            if target_path.is_file():
                target_data = read_json(str(target_path))
                new_data = build_translation(en_data, target_data, key_order)
                write_json(str(target_path), new_data)
                print(f"✔ Updated: {target_path}")
        except Exception as e:
            print(f"❌ Failed processing {target_path}: {e}")

# 🔁 Run the translation update
if __name__ == "__main__":
    process_root(ROOT_DIR)
