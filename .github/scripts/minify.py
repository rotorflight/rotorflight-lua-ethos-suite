#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys

# Absolute path to the luamin binary, override with LUAMIN_CMD env var if needed
LUAMIN_CMD = os.environ.get('LUAMIN_CMD') or shutil.which('luamin') or '/usr/local/lib/node_modules/luamin/bin/luamin'


def minify_lua_file(filepath):
    print(f"[MINIFY] Processing: {filepath}")
    print(f"[MINIFY] Using luamin: {LUAMIN_CMD}")

    if not os.path.isfile(filepath):
        print(f"[MINIFY ERROR] File not found: {filepath}", file=sys.stderr)
        return False

    if not os.path.isfile(LUAMIN_CMD) or not os.access(LUAMIN_CMD, os.X_OK):
        print(f"[MINIFY ERROR] luamin not found at {LUAMIN_CMD}", file=sys.stderr)
        return False

    proc = subprocess.run(
        [LUAMIN_CMD, '-f', filepath],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    if proc.returncode != 0:
        print(f"[MINIFY ERROR] Failed to minify {filepath}: returncode={proc.returncode}", file=sys.stderr)
        print(proc.stderr.strip(), file=sys.stderr)
        return False

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(proc.stdout)

    return True


def main():
    if len(sys.argv) != 2:
        print("Usage: minify.py <absolute-path-to-scripts-dir>", file=sys.stderr)
        sys.exit(1)

    # Use the provided absolute path directly
    target_dir = os.path.abspath(sys.argv[1])
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
    main()
