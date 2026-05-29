#!/usr/bin/env python
import os
import argparse
from pathlib import Path
import shutil
import sys


def debug(msg):
    print(f"[SENSORS DEBUG] {msg}")


def main():
    parser = argparse.ArgumentParser(
        description="Sync sensors.json to the simulator root directory."
    )
    parser.add_argument("--out-dir", required=True, help="Output directory (scripts/<tgt>)")
    parser.add_argument("--lang")
    parser.add_argument("--git-src")
    args = parser.parse_args()

    # out_dir will be: simulators/<fw>@<version>/scripts/rfsuite
    out_dir = Path(args.out_dir).resolve()
    debug(f"Given out_dir = {out_dir}")

    # We want: simulators/<fw>@<version>/
    sim_root = out_dir.parents[1]   # one levels up
    debug(f"Computed simulator root = {sim_root}")

    if args.git_src:
        git_src = Path(args.git_src).resolve()
    else:
        git_src = Path(__file__).resolve().parents[2]

    src = git_src / ".vscode" / "sensors.json"
    dst = sim_root / "sensors.json"
    legacy_sim_sensors = out_dir / "sim" / "sensors"

    debug(f"Source sensors.json = {src} (exists={src.is_file()})")
    debug(f"Destination sensors.json = {dst} (exists={dst.is_file()})")

    if not src.is_file():
        print(f"[SENSORS] No source sensors.json found at {src}")
        return 0

    try:
        if dst.is_file() and src.read_bytes() == dst.read_bytes():
            print(f"[SENSORS] sensors.json already up to date at simulator root.")
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            print(f"[SENSORS] Copied sensors.json to {dst}")

        if legacy_sim_sensors.is_dir():
            shutil.rmtree(legacy_sim_sensors)
            print(f"[SENSORS] Removed legacy simulator sensor directory at {legacy_sim_sensors}")
    except Exception as e:
        print(f"[SENSORS] Sync failed: {e}")
        import traceback
        traceback.print_exc()
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
