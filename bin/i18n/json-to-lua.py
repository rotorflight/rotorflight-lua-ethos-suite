import os
import json
import re
from collections import OrderedDict

JSON_ROOT = "json"
OUT_ROOT = "../../scripts/rfsuite/i18n"
HEADER_PATH = "lib/header.txt"


def read_file_header(path):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read() + "\n\n"
    return ""


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def read_json_file(path):
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
        content = re.sub(r",\s*([}\]])", r"\1", content)  # Remove trailing commas
        return json.loads(content, object_pairs_hook=OrderedDict)


def lua_escape(value):
    value = str(value)
    value = value.replace('\\', '\\\\')  # escape backslashes
    value = value.replace('"', '\\"')     # escape double quotes
    value = value.replace('\n', '\\n')     # escape newlines
    value = value.replace('\r', '\\r')     # escape carriage returns
    return value


def serialize_lua_table(obj, indent="  ", level=0):
    if not isinstance(obj, dict):
        return f'"{lua_escape(obj)}"'

    lines = ["{"]
    keys = list(obj.keys())
    for i, key in enumerate(keys):
        val = obj[key]
        lua_key = f'[{json.dumps(key)}]'

        if isinstance(val, dict):
            lua_val = serialize_lua_table(val, indent, level + 1)
        elif isinstance(val, bool):
            lua_val = "true" if val else "false"
        elif isinstance(val, (int, float)):
            lua_val = str(val)
        else:
            lua_val = f'"{lua_escape(val)}"'

        comma = "," if i < len(keys) - 1 else ""
        lines.append(f'{indent * (level + 1)}{lua_key} = {lua_val}{comma}')

    lines.append(indent * level + "}")
    return "\n".join(lines)


def collect_json_files():
    json_files = []
    for root, _, files in os.walk(JSON_ROOT):
        for file in files:
            if file.endswith(".json"):
                lang = file[:-5]
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, JSON_ROOT)
                rel_dir = os.path.dirname(rel_path)
                json_files.append({
                    "lang": lang,
                    "path": full_path,
                    "rel_dir": rel_dir
                })
    return json_files


def insert_nested(target, rel_dir, value):
    parts = rel_dir.split(os.sep) if rel_dir else []
    current = target
    for part in parts:
        current = current.setdefault(part, OrderedDict())
    for k, v in value.items():
        current[k] = v


def process_json_content(lang, content):
    def extract(node):
        if isinstance(node, dict):
            result = OrderedDict()
            for k, v in node.items():
                if isinstance(v, dict) and ("english" in v or "translation" in v):
                    if lang == "en":
                        result[k] = v.get("english", "")
                    else:
                        result[k] = v.get("translation", "")
                else:
                    result[k] = extract(v)
            return result
        return node

    return extract(content)


def build_language_tables():
    translations = {}
    all_files = collect_json_files()

    for file_info in all_files:
        lang = file_info["lang"]
        rel_dir = file_info["rel_dir"]
        data = read_json_file(file_info["path"])
        processed = process_json_content(lang, data)
        translations.setdefault(lang, OrderedDict())
        insert_nested(translations[lang], rel_dir, processed)

    return translations


def write_lua_files():
    header = read_file_header(HEADER_PATH)
    translations = build_language_tables()
    ensure_dir(OUT_ROOT)

    for lang, data in translations.items():
        out_path = os.path.join(OUT_ROOT, f"{lang}.lua")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(header)
            f.write("return ")
            f.write(serialize_lua_table(data))
            f.write("\n")
        print("✔ Wrote:", out_path)


if __name__ == "__main__":
    write_lua_files()