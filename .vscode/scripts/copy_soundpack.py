#!/usr/bin/env python3
import argparse, os, shutil, time, hashlib, sys
from tqdm import tqdm

TS_SLACK = 2.0  # FAT/exFAT timestamp slack (seconds)

def file_md5(path, chunk=1024 * 1024):
    h = hashlib.md5()
    with open(path, 'rb', buffering=0) as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()

def needs_copy_with_md5(srcf, dstf):
    try:
        ss = os.stat(srcf)
    except FileNotFoundError:
        return False
    if not os.path.exists(dstf):
        return True
    try:
        ds = os.stat(dstf)
    except FileNotFoundError:
        return True
    if ss.st_size != ds.st_size:
        return True
    if (ss.st_mtime - ds.st_mtime) > TS_SLACK:
        return True
    try:
        return file_md5(srcf) != file_md5(dstf)
    except Exception:
        return True

def copy_tree_update_only(src, dest):
    os.makedirs(dest, exist_ok=True)

    files = []
    for r, _, fs in os.walk(src):
        for f in fs:
            s = os.path.join(r, f)
            rel = os.path.relpath(s, src)
            d = os.path.join(dest, rel)
            files.append((s, d))

    if not files:
        print("[AUDIO] No files to copy.")
        return

    bar = tqdm(total=len(files), desc="Copying soundpack")
    for s, d in files:
        os.makedirs(os.path.dirname(d), exist_ok=True)
        if needs_copy_with_md5(s, d):
            shutil.copy2(s, d)
        bar.update(1)
    bar.close()

def main():
    ap = argparse.ArgumentParser(description="Copy language soundpack")
    ap.add_argument("src", help="Source folder (e.g. bin/sound-generator/soundpack/en)")
    ap.add_argument("dest", help="Destination folder (e.g. scripts/rfsuite/audio/en)")
    args = ap.parse_args()

    src = os.path.normpath(args.src)
    dest = os.path.normpath(args.dest)

    if not os.path.isdir(src):
        print(f"[AUDIO] Source not found: {src}")
        return 1

    print(f"[AUDIO] Source: {src}")
    print(f"[AUDIO] Dest  : {dest}")
    copy_tree_update_only(src, dest)

    try:
        if hasattr(os, "sync"):
            os.sync()
    except Exception:
        pass
    time.sleep(0.1)
    print("[AUDIO] Done.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
