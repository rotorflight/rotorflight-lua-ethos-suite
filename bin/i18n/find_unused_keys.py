import os
import re
import json

LUA_SOURCE_DIR = "../../scripts/rfsuite/"
I18N_JSON_DIR = "./json"

def flatten_dict(d, parent_key='', sep='.'):
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def load_i18n_keys(json_dir):
    all_keys = set()
    for root, _, files in os.walk(json_dir):
        for file in files:
            if file == "en.json":
                with open(os.path.join(root, file), "r", encoding="utf-8") as f:
                    try:
                        data = json.load(f)
                        all_keys.update(flatten_dict(data).keys())
                    except Exception as e:
                        print(f"[ERROR] Failed to parse {file}: {e}")
    return all_keys

def scan_lua_for_keys(lua_dir):
    used_keys = set()
    pattern = re.compile(r'i18n\.get\(\s*["\'](.*?)["\']\s*\)')

    for root, _, files in os.walk(lua_dir):
        for file in files:
            if file.endswith(".lua"):
                full_path = os.path.join(root, file)
                try:
                    with open(full_path, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            used_keys.update(pattern.findall(line))
                except Exception as e:
                    print(f"[ERROR] Failed to read {full_path}: {e}")
    return used_keys

if __name__ == "__main__":
    i18n_keys = load_i18n_keys(I18N_JSON_DIR)
    used_keys = scan_lua_for_keys(LUA_SOURCE_DIR)

    unused = sorted(i18n_keys - used_keys)

    print(f"🧹 Found {len(unused)} unused i18n keys:\n")
    for key in unused:
        print(key)
