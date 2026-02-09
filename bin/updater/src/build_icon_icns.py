#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate a macOS .icns file from the Windows .ico source.
Requires Pillow. Runs on macOS (uses iconutil).
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except Exception as e:
    print(f"ERROR: Pillow is required (pip install pillow). {e}")
    sys.exit(1)


def main() -> int:
    here = Path(__file__).resolve().parent
    src = here / "icon.ico"
    out = here / "icon.icns"

    if not src.is_file():
        print(f"ERROR: Missing source icon: {src}")
        return 1

    if sys.platform != "darwin":
        print("ERROR: iconutil is macOS-only. Run this on macOS.")
        return 1

    if shutil.which("iconutil") is None:
        print("ERROR: iconutil not found. It should be present on macOS.")
        return 1

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    base_pairs = [
        (16, 32),
        (32, 64),
        (128, 256),
        (256, 512),
        (512, 1024),
    ]

    with tempfile.TemporaryDirectory(prefix="rfsuite-icon-") as tmp:
        iconset = Path(tmp) / "icon.iconset"
        iconset.mkdir(parents=True, exist_ok=True)

        img = Image.open(src).convert("RGBA")
        # Generate size set
        for size in sizes:
            resized = img.resize((size, size), Image.LANCZOS)
            resized.save(iconset / f"icon_{size}x{size}.png")

        # Generate @2x entries for base sizes
        for base, dbl in base_pairs:
            src_path = iconset / f"icon_{dbl}x{dbl}.png"
            dst_path = iconset / f"icon_{base}x{base}@2x.png"
            shutil.copyfile(src_path, dst_path)

        cmd = ["iconutil", "-c", "icns", str(iconset), "-o", str(out)]
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.returncode != 0:
            print("ERROR: iconutil failed")
            if result.stdout:
                print(result.stdout.strip())
            if result.stderr:
                print(result.stderr.strip())
            return 1

    print(f"OK: wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
