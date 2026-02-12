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

def _contains_hebrew_chars(s: str) -> bool:
    return re.search(r"[\u0590-\u05FF]", s) is not None

def _should_add_reverse_text(locale: str) -> bool:
    return True

def _maybe_set_reverse_text(entry: OrderedDict, locale: str):
    if not _should_add_reverse_text(locale):
        return
    if "reverse_text" in entry:
        return
    locale_norm = locale.strip().lower().replace("_", "-")
    translation = entry.get("translation")
    if locale_norm == "he" and isinstance(translation, str):
        entry["reverse_text"] = _contains_hebrew_chars(translation)
        return
    entry["reverse_text"] = False

def build_translation(ref, target, order, locale: str):
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
                _maybe_set_reverse_text(entry, locale)
                output[key] = entry
            else:
                entry = OrderedDict({
                    "english": ref_val["english"],
                    "translation": ref_val["english"],
                    "needs_translation": True
                })
                _maybe_set_reverse_text(entry, locale)
                output[key] = entry
        elif isinstance(ref_val, dict):
            output[key] = build_translation(ref_val, tgt_val or {}, order.get(key, {"__order": []}), locale)
        else:
            output[key] = ref_val
    return output

def _parse_args():
    import argparse
    ap = argparse.ArgumentParser(description="Update i18n JSON files and preserve translation structure.")
    ap.add_argument("--only", nargs="*", help="Limit to specific locales (e.g. --only he)")
    return ap.parse_args()

def process_root(path: Path, only_locales=None):
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
        if only_locales and target_path.stem not in only_locales:
            continue
        try:
            if target_path.is_file():
                target_data = read_json(str(target_path))
                new_data = build_translation(en_data, target_data, key_order, target_path.stem)
                write_json(str(target_path), new_data)
                print(f"✔ Updated: {target_path}")
        except Exception as e:
            print(f"❌ Failed processing {target_path}: {e}")

# 🔁 Run the translation update
if __name__ == "__main__":
    args = _parse_args()
    process_root(ROOT_DIR, set(args.only or []))
