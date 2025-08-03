```python
#!/usr/bin/env python3
import os
import shutil
import subprocess
import sys

# Default path to the locally-installed luamin
LOCAL_LUAMIN = os.path.join(os.getcwd(), 'node_modules', '.bin', 'luamin')


def minify_lua_file(filepath, luamin_cmd=None):
    print(f"[MINIFY] Processing: {filepath}")

    # Determine luamin executable (override via LUAMIN_CMD env)
    if not luamin_cmd:
        # 1) Use explicit env override if given
        luamin_cmd = os.environ.get('LUAMIN_CMD')
        # 2) Use local node_modules/.bin
        if not luamin_cmd and os.path.isfile(LOCAL_LUAMIN) and os.access(LOCAL_LUAMIN, os.X_OK):
            luamin_cmd = LOCAL_LUAMIN
        # 3) Fallback to global PATH
        if not luamin_cmd:
            luamin_cmd = shutil.which('luamin')
        # 4) Windows global npm fallback
        if not luamin_cmd:
            win_bin = os.path.expandvars(r"%APPDATA%\\npm\\luamin.cmd")
            if os.path.isfile(win_bin) and os.access(win_bin, os.X_OK):
                luamin_cmd = win_bin

    if not luamin_cmd:
        print("[MINIFY ERROR] 'luamin' not found. Tried env LUAMIN_CMD, local node_modules/.bin, PATH, and %APPDATA%\\npm.", file=sys.stderr)
        print("Please install luamin (e.g. npm ci or npm install -g luamin)", file=sys.stderr)
        return False

    try:
        # Run luamin and capture output
        result = subprocess.run(
            [luamin_cmd, '-f', filepath],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding='utf-8',
            errors='replace'
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
```
