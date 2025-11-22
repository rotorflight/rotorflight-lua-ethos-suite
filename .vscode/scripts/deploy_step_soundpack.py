#!/usr/bin/env python
import os
import sys
import argparse
import time
import hashlib
from pathlib import Path

import shutil
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
    parser = argparse.ArgumentParser(
        description="Copy the language-specific soundpack into the output directory."
    )
    parser.add_argument("--out-dir", required=True, help="Output directory (root of rfsuite).")
    parser.add_argument("--lang", default="en", help="Language code, e.g. en, fr, de.")
    parser.add_argument(
        "--git-src",
        help="Workspace root; if omitted, will be inferred from this script location.",
    )
    args = parser.parse_args()

    out_dir = os.path.abspath(args.out_dir)
    lang = args.lang

    if args.git_src:
        git_src = os.path.abspath(args.git_src)
    else:
        # Assume this script is: <git_src>/.vscode/scripts/deploy_step_soundpack.py
        git_src = str(Path(__file__).resolve().parents[2])

    src = os.path.join(git_src, "bin", "sound-generator", "soundpack", lang)
    dest = os.path.join(out_dir, "audio", lang)

    if not os.path.isdir(src):
        print(f"[AUDIO] Skipping: soundpack not found at {src}")
        return 0

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
