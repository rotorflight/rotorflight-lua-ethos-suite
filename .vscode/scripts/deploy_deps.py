"""
Make sure the Python packages the deploy scripts use are installed.

Runs before deploy.py imports anything third-party. Missing packages are
pip-installed into the interpreter running the deploy (the one VS Code
picked), then deploy.py is re-run so new .pth paths (pywin32) take effect.
Every failure is non-fatal: deploy.py already falls back when tqdm, pyserial
or HID support is missing, so an offline machine still deploys by drive scan.

HID uses the `hidapi` package, whose wheels include the native hidapi
library. The older `hid` package is only a wrapper that needs hidapi.dll
(Windows) or `brew install hidapi` (macOS) installed separately; if it is
installed but cannot load that library it is replaced with `hidapi`.
"""

import importlib
import importlib.util
import os
import subprocess
import sys

_RERUN_ENV = "ETHOS_DEPLOY_DEPS_RERUN"


def _missing(module):
    return importlib.util.find_spec(module) is None


def _hid_ok():
    """True if `import hid` gives a usable module from either package."""
    try:
        import hid
    except Exception:
        return False
    return hasattr(hid, "device") or hasattr(hid, "Device")


def _dist_installed(name):
    try:
        from importlib import metadata
        metadata.version(name)
        return True
    except Exception:
        return False


def _pip(args):
    cmd = [sys.executable, "-m", "pip", *args,
           "--disable-pip-version-check", "--timeout", "15", "--retries", "1"]
    print("[DEPS] " + " ".join(cmd[1:]), flush=True)
    try:
        return subprocess.run(cmd).returncode == 0
    except Exception as e:
        print(f"[DEPS] pip failed to start: {e}")
        return False


def _install(packages):
    if _pip(["install", *packages]):
        return True
    if sys.prefix != sys.base_prefix:
        return False  # a virtualenv cannot take --user installs
    # A system-wide Python (e.g. under Program Files) may need a user install.
    return _pip(["install", "--user", *packages])


def ensure_dependencies():
    """Install whatever is missing. Returns True if deploy.py should be re-run."""
    if os.environ.get(_RERUN_ENV):
        return False

    needed = []
    if _missing("tqdm"):
        needed.append("tqdm")
    if _missing("serial"):
        needed.append("pyserial")
    if sys.platform == "win32" and (_missing("win32api") or _missing("win32file")):
        needed.append("pywin32")

    replace_hid = False
    if not _hid_ok():
        # The `hid` package imports as `hid` too and shadows hidapi, so a broken
        # copy (no native library) has to go before hidapi can be used.
        replace_hid = _dist_installed("hid")
        needed.append("hidapi")

    if not needed:
        return False

    print(f"[DEPS] Installing missing Python packages: {', '.join(needed)}")
    if replace_hid:
        print("[DEPS] Removing the 'hid' package: it needs a separately installed hidapi library")
        _pip(["uninstall", "-y", "hid"])

    if not _install(needed):
        print("[DEPS] Automatic install failed; continuing without these packages.")
        print(f"[DEPS] To install by hand: \"{sys.executable}\" -m pip install {' '.join(needed)}")
        return False

    print("[DEPS] Packages installed.")
    return True


def rerun_if_installed():
    """Call at the top of deploy.py; re-runs it once if packages were installed."""
    try:
        if not ensure_dependencies():
            return
    except Exception as e:
        print(f"[DEPS] Dependency check failed ({type(e).__name__}: {e}); continuing.")
        return
    importlib.invalidate_caches()
    env = dict(os.environ)
    env[_RERUN_ENV] = "1"
    sys.stdout.flush()
    result = subprocess.run([sys.executable, *sys.argv], env=env)
    sys.exit(result.returncode)
