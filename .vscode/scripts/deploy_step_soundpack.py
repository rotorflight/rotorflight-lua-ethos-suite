#!/usr/bin/env python
import os
import sys
import argparse
import shutil
import subprocess
from pathlib import Path


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
    script = os.path.join(git_src, ".vscode", "scripts", "copy_soundpack.py")

    if not os.path.isdir(src):
        print(f"[AUDIO] Skipping: soundpack not found at {src}")
        return 0

    os.makedirs(dest, exist_ok=True)

    try:
        if os.path.isfile(script):
            print(f"[AUDIO] Copying soundpack ({lang}) → {dest}")
            subprocess.run([sys.executable, script, src, dest], check=True)
        else:
            print(f"[AUDIO] Standalone script not found at {script}; doing simple copy.")
            shutil.copytree(src, dest, dirs_exist_ok=True)
    except subprocess.CalledProcessError as e:
        print(f"[AUDIO] copy_soundpack.py failed: {e}")
    except Exception as e:
        print(f"[AUDIO] Fallback copy failed: {e}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
