# i18n/build-single-json.py
#!/usr/bin/env python3
import os, json

JSON_ROOT = os.path.join(os.path.dirname(__file__), "json")
OUT_PATH  = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "scripts", "rfsuite", "i18n", "en.json"))

def ensure_dir(p):
    os.makedirs(os.path.dirname(p), exist_ok=True)

def insert_nested(root, rel_dir, leaf):
    cur = root
    if rel_dir and rel_dir != ".":
        for part in rel_dir.replace("\\","/").split("/"):
            if not part:
                continue
            cur = cur.setdefault(part, {})
    for k, v in leaf.items():
        if isinstance(v, dict):
            cur[k] = {**cur.get(k, {}), **v}
        else:
            cur[k] = v
    return root

def main():
    combined = {}
    for dirpath, _, files in os.walk(JSON_ROOT):
        rel_dir = os.path.relpath(dirpath, JSON_ROOT)
        for fn in files:
            if fn.lower() != "en.json":
                continue
            with open(os.path.join(dirpath, fn), "r", encoding="utf-8") as f:
                data = json.load(f)
            insert_nested(combined, rel_dir, data)

    ensure_dir(OUT_PATH)
    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(combined, f, ensure_ascii=False, indent=2, sort_keys=True)
    print("✔ Wrote", OUT_PATH)

if __name__ == "__main__":
    main()
