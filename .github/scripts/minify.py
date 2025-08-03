#!/usr/bin/env python3
import os
import subprocess
import sys

# Path to the locally-installed luamin binary
LUAMIN_CMD = os.path.join(os.getcwd(), 'node_modules', '.bin', 'luamin')


def minify_lua_file(filepath):
    print(f"[MINIFY] Processing: {filepath}")

    # Verify the luamin binary exists and is executable
    if not os.path.isfile(LUAMIN_CMD) or not os.access(LUAMIN_CMD, os.X_OK):
        print(f"[MINIFY ERROR] luamin not found at {LUAMIN_CMD}", file=sys.stderr)
        return False

    # Run luamin, capturing stdout and stderr
    result = subprocess.run(
        [LUAMIN_CMD, '-f', filepath],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    if result.returncode != 0:
        print(f"[MINIFY ERROR] Failed to minify {filepath}:\n{result.stderr}", file=sys.stderr)
        return False

    # Overwrite the original file with the minified output
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(result.stdout)

    return True


def main(root='scripts'):
    failures = 0
    for dirpath, _, files in os.walk(root):
        for fn in files:
            if fn.endswith('.lua'):
                path = os.path.join(dirpath, fn)
                if not minify_lua_file(path):
                    failures += 1

    if failures:
        sys.exit(1)


if __name__ == '__main__':
    root_dir = sys.argv[1] if len(sys.argv) > 1 else 'scripts'
    main(root_dir)