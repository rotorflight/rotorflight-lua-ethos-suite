#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys

# Locate luamin binary: try PATH then node_modules/.bin
LUAMIN_CMD = shutil.which('luamin') or os.path.join(os.path.dirname(__file__), '..', '..', 'node_modules', '.bin', 'luamin')


def minify_lua_file(filepath):
    print(f"[MINIFY] Processing: {filepath}")
    print(f"[MINIFY] Using luamin: {LUAMIN_CMD}")

    # Verify binary
    if not os.path.isfile(LUAMIN_CMD) or not os.access(LUAMIN_CMD, os.X_OK):
        print(f"[MINIFY ERROR] luamin not found or not executable at {LUAMIN_CMD}", file=sys.stderr)
        return False

    # Show version for debugging
    try:
        version = subprocess.check_output([LUAMIN_CMD, '--version'], text=True).strip()
        print(f"[MINIFY] luamin version: {version}")
    except Exception as e:
        print(f"[MINIFY WARNING] could not get luamin version: {e}")

    # Run luamin
    proc = subprocess.run(
        [LUAMIN_CMD, '-f', filepath],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    if proc.returncode != 0:
        print(f"[MINIFY ERROR] Failed to minify {filepath}: returncode={proc.returncode}", file=sys.stderr)
        print("--- stderr ---", file=sys.stderr)
        print(proc.stderr, file=sys.stderr)
        print("--- stdout ---", file=sys.stderr)
        print(proc.stdout, file=sys.stderr)
        return False

    # Overwrite original
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(proc.stdout)
    return True


def main(root='scripts'):
    # Resolve repo root
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
    target_dir = os.path.join(repo_root, root)
    print(f"[MINIFY] Target directory: {target_dir}")

    failures = 0
    for dirpath, _, files in os.walk(target_dir):
        for fn in files:
            if fn.endswith('.lua'):
                path = os.path.join(dirpath, fn)
                if not minify_lua_file(path):
                    failures += 1

    if failures:
        print(f"[MINIFY] Completed with {failures} failures", file=sys.stderr)
        sys.exit(1)
    else:
        print("[MINIFY] All files minified successfully.")


if __name__ == '__main__':
    root_arg = sys.argv[1] if len(sys.argv) > 1 else 'scripts'
    main(root_arg)
