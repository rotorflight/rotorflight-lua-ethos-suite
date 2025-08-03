#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys

def minify_lua_file(filepath):
    print(f"[MINIFY] Processing: {filepath}")

    # Locate luamin executable
    luamin_cmd = shutil.which("luamin")
    if not luamin_cmd:
        # Fallback for Windows NPM global installs
        luamin_cmd = os.path.expandvars(r"%APPDATA%\\npm\\luamin.cmd")
        if not os.path.exists(luamin_cmd):
            print("[MINIFY ERROR] 'luamin' not found in PATH or %APPDATA%\\npm.", file=sys.stderr)
            print("Please run: npm install -g luamin", file=sys.stderr)
            return False

    try:
        # Run luamin and capture output
        result = subprocess.run(
            [luamin_cmd, '-f', filepath],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding='utf-8',  # force proper decoding
            errors='replace'   # replace invalid chars
        )

        if result.returncode != 0:
            print(f"[MINIFY ERROR] Failed to minify {filepath}:\n{result.stderr}", file=sys.stderr)
            return False

        # Overwrite original file with minified output
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(result.stdout)
        return True

    except Exception as e:
        print(f"[MINIFY ERROR] Exception during luamin run: {e}", file=sys.stderr)
        return False


def main(root='scripts'):
    # Walk and minify all .lua under the given root
    failures = 0
    for dirpath, _, files in os.walk(root):
        for fn in files:
            if fn.endswith('.lua'):
                path = os.path.join(dirpath, fn)
                if not minify_lua_file(path):
                    failures += 1

    # Exit with failure code if any files failed
    if failures:
        sys.exit(1)

if __name__ == '__main__':
    # Optionally accept a custom root directory as an argument
    root_dir = sys.argv[1] if len(sys.argv) > 1 else 'scripts'
    main(root_dir)
