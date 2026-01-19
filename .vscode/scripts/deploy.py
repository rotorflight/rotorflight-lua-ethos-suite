import os
import shutil
import argparse
import json
import subprocess
import subprocess_conout
import sys
import stat
from tqdm import tqdm
import re
import shlex
import time
import atexit, signal, tempfile
import platform
from hashlib import md5
from glob import glob
from pathlib import Path

MIN_ETHOSSUITE_VERSION = "1.7.0"

SERIAL_PIDFILE = os.path.join(tempfile.gettempdir(), "deploy-serial.pid")
DEPLOY_TO_RADIO = False  # flag to control radio-only behavior
THROTTLE_EXTS = None  # unused when throttling all copies
THROTTLE_MIN_BYTES = 0  # unused when throttling all copies
THROTTLE_CHUNK = 32 * 1024          # 32 KiB
THROTTLE_PAUSE_EVERY = 64 * 1024    # pause+fsync every 64 KiB written
THROTTLE_PAUSE_S = 0.1              # 100 ms

# --- single-instance lock helpers --------------------------------------------
LOCK_DEFAULT_NAME = "deploy.single.lock"
if os.name == "nt":
    import msvcrt
else:
    import fcntl

def _lock_file(fd):
    if os.name == "nt":
        msvcrt.locking(fd.fileno(), msvcrt.LK_NBLCK, 1)
    else:
        fcntl.flock(fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)

def _unlock_file(fd):
    try:
        if os.name == "nt":
            fd.seek(0)
            msvcrt.locking(fd.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            fcntl.flock(fd.fileno(), fcntl.LOCK_UN)
    except OSError:
        pass

def _pid_is_running(pid: int) -> bool:
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False

class SingleInstance:
    """OS-level file lock + PID metadata to ensure only one deploy.py instance."""
    def __init__(self, name: str = LOCK_DEFAULT_NAME, force: bool = False):
        self.lock_path = os.path.join(tempfile.gettempdir(), name)
        self.force = force
        self.fd = None
        self._acquired = False

    def acquire(self):
        self.fd = open(self.lock_path, "a+")
        self.fd.seek(0)
        try:
            _lock_file(self.fd)
            self._acquired = True
        except OSError:
            # Check if the current holder is stale
            self.fd.seek(0)
            holder_pid = -1
            try:
                import json as _json
                meta = (self.fd.read() or "").strip()
                data = _json.loads(meta) if meta else {}
                holder_pid = int(data.get("pid", -1))
            except Exception:
                pass
            if holder_pid > 0 and not _pid_is_running(holder_pid):
                if not self.force:
                    raise RuntimeError(
                        f"Another deploy appears to be running (stale lock from PID {holder_pid}). "
                        f"Re-run with --force to take over. Lock: {self.lock_path}"
                    )
                time.sleep(0.2)
                _lock_file(self.fd)
                self._acquired = True
            else:
                raise RuntimeError(
                    f"Another deploy is already running (PID {holder_pid if holder_pid>0 else 'unknown'})."
                )
        # record metadata
        try:
            self.fd.seek(0); self.fd.truncate(0)
            import json as _json
            _json.dump({"pid": os.getpid(), "time": time.time(), "host": platform.node()}, self.fd)
            self.fd.flush(); os.fsync(self.fd.fileno())
        except Exception:
            pass
        atexit.register(self.release)
        for sig in (signal.SIGINT, signal.SIGTERM):
            try:
                signal.signal(sig, self._signal_and_release)
            except Exception:
                pass

    def _signal_and_release(self, signum, frame):
        self.release()
        signal.signal(signum, signal.SIG_DFL)
        os.kill(os.getpid(), signum)

    def release(self):
        if self._acquired and self.fd:
            try:
                self.fd.seek(0); self.fd.truncate(0); self.fd.flush()
                _unlock_file(self.fd)
            finally:
                try: self.fd.close()
                except Exception: pass
                try: os.remove(self.lock_path)
                except Exception: pass
            self._acquired = False

def _lock_path_for_config(config_path: str) -> str:
    """Compute the exact lock file path used for this project/config."""
    proj_key = md5(os.path.abspath(config_path).encode("utf-8")).hexdigest()[:8]
    lock_name = f"deploy-{proj_key}.lock"
    return os.path.join(tempfile.gettempdir(), lock_name)

def parse_version(v: str):
    return tuple(map(int, v.split(".")))

def check_ethossuite_version(ethossuite_bin, min_version=MIN_ETHOSSUITE_VERSION):
    try:
        res = subprocess.run(
            [ethossuite_bin, "--version"],
            text=True,
            capture_output=True,
            timeout=10
        )
    except FileNotFoundError:
        print(f"[ERROR] Ethos Suite not found at: {ethossuite_bin}")
        return False
    except subprocess.TimeoutExpired:
        print("[ERROR] Ethos Suite --version timed out.")
        return False

    if res.returncode != 0:
        print(f"[ERROR] Ethos Suite exited with code {res.returncode}")
        return False

    lines = [l.strip() for l in (res.stdout or "").splitlines() if l.strip()]
    version = next((l for l in lines if re.match(r'^\d+\.\d+\.\d+$', l)), None)

    if not version:
        print(f"[ERROR] Could not parse Ethos Suite version from output:\n{res.stdout}")
        return False

    if parse_version(version) < parse_version(min_version):
        print(f"[ERROR] Ethos Suite version {version} is too old (need >= {min_version})")
        return False

    print(f"[ETHOS] Detected Ethos Suite version {version} ✓")
    return True


def file_md5(path, chunk=1024 * 1024):
    import hashlib
    h = hashlib.md5()
    with open(path, 'rb', buffering=0) as f:
        while True:
            b = f.read(chunk)
            if not b:
                break
            h.update(b)
    return h.hexdigest()

def _kill_previous_tail_if_any():
    try:
        with open(SERIAL_PIDFILE, "r") as f:
            old = int((f.read() or "0").strip())
    except Exception:
        return
    if old and old != os.getpid():
        try:
            if os.name == "nt":
                subprocess.run(["taskkill", "/PID", str(old), "/T", "/F"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                os.kill(old, signal.SIGTERM)
                time.sleep(0.3)
                try: os.kill(old, signal.SIGKILL)
                except Exception: pass
        except Exception:
            pass
    try: os.remove(SERIAL_PIDFILE)
    except Exception: pass

def _record_tail_pid_and_cleanup():
    try:
        with open(SERIAL_PIDFILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass
    atexit.register(lambda: os.path.exists(SERIAL_PIDFILE) and os.remove(SERIAL_PIDFILE))


def throttled_copyfile(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    written_since_pause = 0
    with open(src, 'rb', buffering=0) as fsrc, open(dst, 'wb', buffering=0) as fdst:
        while True:
            chunk = fsrc.read(THROTTLE_CHUNK)
            if not chunk:
                break
            fdst.write(chunk)
            written_since_pause += len(chunk)
            if written_since_pause >= THROTTLE_PAUSE_EVERY:
                fdst.flush()
                try:
                    os.fsync(fdst.fileno())
                except OSError:
                    pass
                time.sleep(THROTTLE_PAUSE_S)
                written_since_pause = 0

        fdst.flush()
        try:
            os.fsync(fdst.fileno())
        except OSError:
            pass

    try:
        shutil.copymode(src, dst)
    except Exception:
        pass

def scan_usb_drives_for_radio():
    """
    Strong fallback: scan mounted drives for:
      - radio.bin (file)
      - scripts/  (directory)
    Returns the scripts directory path or None.
    """
    import string
    candidates = []

    print("[ETHOS] Performing fallback USB drive scan for radio…")

    if os.name == "nt":
        for letter in string.ascii_uppercase:
            root = f"{letter}:\\"
            try:
                if (
                    os.path.isdir(os.path.join(root, "scripts"))
                ):
                    candidates.append(os.path.normpath(os.path.join(root, "scripts")))
            except Exception:
                pass
    else:
        for base in ("/Volumes", "/media", "/mnt"):
            if not os.path.isdir(base):
                continue
            for entry in os.listdir(base):
                root = os.path.join(base, entry)
                try:
                    if (
                        os.path.isfile(os.path.join(root, "radio.bin")) and
                        os.path.isdir(os.path.join(root, "scripts"))
                    ):
                        candidates.append(os.path.normpath(os.path.join(root, "scripts")))
                except Exception:
                    pass

    if candidates:
        print(f"[ETHOS] Fallback USB scan found radio at: {candidates[0]}")
        return candidates[0]
    return None



def get_ethos_scripts_dir(ethossuite_bin, retries=1, delay=5):
    """
    Ask Ethos Suite for the SCRIPTS path. Robust against chatty output.
    """
    import re, json

    cmd = [ethossuite_bin, "--get-path", "SCRIPTS", "--radio", "auto"]
    path_re = re.compile(r'^(?:[A-Za-z]:\\|\\\\\?\\|//|/)[^\r\n]+$')

    def _clean(line: str) -> str:
        line = (line or "").strip().strip('"').strip("'")
        if not line:
            return ""
        low = line.lower()
        if low.startswith("exit code"):
            return ""
        if low.startswith("new removable disks"):
            return line  # keep for JSON parse
        if line.startswith("{") or line.startswith("["):
            return line
        return line


    last_err = None
    for attempt in range(retries + 1):
        try:
            res = subprocess.run(cmd, text=True, capture_output=True, timeout=20)
            if res.returncode != 0:
                raise subprocess.CalledProcessError(res.returncode, cmd, output=res.stdout, stderr=res.stderr)

            raw = res.stdout or ""
            lines = [_clean(l) for l in raw.splitlines() if l.strip()]
            candidates = [l for l in lines if path_re.match(l)]
            existing = [os.path.normpath(p) for p in candidates if os.path.isdir(os.path.normpath(p))]
            if existing:
                preferred = [p for p in existing if os.path.basename(p).lower() == "scripts"]
                return preferred[0] if preferred else existing[0]
            if candidates:
                preferred = [p for p in candidates if "scripts" in p.lower()]
                return os.path.normpath(preferred[0] if preferred else candidates[0])

            blob_lines = [l for l in lines if l.lower().startswith("new removable disks")]
            if blob_lines:
                blob = blob_lines[-1]
                try:
                    start = blob.index('['); end = blob.rindex(']') + 1
                    arr = json.loads(blob[start:end])
                    choice = None
                    for item in arr:
                        if item.get("radioDisk") == "radio":
                            choice = item; break
                    if not choice and arr:
                        choice = arr[0]
                    if choice:
                        mps = choice.get("mountpoints") or []
                        for mp in mps:
                            p = (mp.get("path") or "").strip()
                            if p:
                                scripts = os.path.normpath(os.path.join(p, "scripts"))
                                return scripts
                except Exception:
                    pass

            # Final fallback: explicit USB scan
            fallback = scan_usb_drives_for_radio()
            if fallback:
                return fallback

            raise RuntimeError("No path-like output from Ethos Suite and no valid radio drive found.")
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired, RuntimeError) as e:
            last_err = e
            if attempt < retries:
                print(f"[ETHOS] Could not get SCRIPTS path (attempt {attempt+1}/{retries+1}). Retrying in {delay}s…")
                time.sleep(delay)
            else:
                raise last_err

            # IMPORTANT: also attempt USB fallback when Ethos Suite fails (non-zero/timeout/etc)
            fb = scan_usb_drives_for_radio()
            if fb:
                return fb



def on_rm_error(func, path, exc_info):
    """Resilient rm error handler."""
    e = exc_info[1]
    if isinstance(e, FileNotFoundError):
        return
    try:
        os.chmod(path, stat.S_IWRITE)
    except FileNotFoundError:
        return

    for i in range(5):
        try:
            func(path)
            return
        except FileNotFoundError:
            return
        except OSError as oe:
            if getattr(oe, "winerror", 0) in (5, 32, 483):
                time.sleep(0.2 * (i + 1))
                continue
            raise


def flush_fs():
    """Attempt to flush filesystem buffers (best-effort)."""
    try:
        if hasattr(os, "sync"):
            os.sync()
    except Exception as e:
        print(f"[WARN] os.sync failed: {e}")


DELETE_BATCH = 1
DELETE_PAUSE_S = 0.10  # 100ms

def throttled_rmtree(root, batch=DELETE_BATCH, pause=DELETE_PAUSE_S):
    if not os.path.exists(root):
        return
    files = []
    for dp, _, fs in os.walk(root):
        for f in fs:
            files.append(os.path.join(dp, f))

    bar = tqdm(total=len(files), desc="Deleting")
    for i, p in enumerate(files, 1):
        try:
            os.chmod(p, stat.S_IWRITE)
        except Exception:
            pass

        attempt = 0
        while True:
            try:
                os.unlink(p)
                break
            except FileNotFoundError:
                break
            except OSError as oe:
                if getattr(oe, "winerror", 0) in (5, 32, 483) and attempt < 5:
                    time.sleep(pause * (attempt + 1))
                    attempt += 1
                    continue
                break

        bar.update(1)
        if i % batch == 0:
            flush_fs()
            time.sleep(pause)

    bar.close()

    for dp, dns, _ in sorted(os.walk(root), key=lambda t: t[0], reverse=True):
        for d in dns:
            try:
                os.rmdir(os.path.join(dp, d))
            except Exception:
                pass
    try:
        os.rmdir(root)
    except Exception:
        pass
    flush_fs()
    time.sleep(pause)


def delete_tree(path):
    if not os.path.isdir(path):
        return
    if DEPLOY_TO_RADIO:
        throttled_rmtree(path)
    else:
        shutil.rmtree(path, onerror=on_rm_error)
        flush_fs()
        time.sleep(DELETE_PAUSE_S)


def safe_full_copy(srcall, out_dir):
    """Safer full-copy for slow FAT32 targets."""
    global pbar
    if os.path.isdir(out_dir):
        old_dir = out_dir + ".old"

        if os.path.isdir(old_dir):
            print("Deleting previous backup…")
            delete_tree(old_dir)
            flush_fs()
            time.sleep(2)

        try:
            print(f"Renaming existing to {os.path.basename(old_dir)}…")
            os.replace(out_dir, old_dir)
        except Exception as e:
            print(f"[WARN] Rename failed ({e}). Falling back to direct delete.")
            print("Deleting files…")
            delete_tree(out_dir)
        flush_fs()
        time.sleep(2)

        if os.path.isdir(old_dir):
            print("Deleting files…")
            delete_tree(old_dir)
            flush_fs()
            time.sleep(2)

    print("Copying files…")
    total = count_files(srcall)
    pbar = tqdm(total=total)
    shutil.copytree(srcall, out_dir, dirs_exist_ok=True, copy_function=copy_verbose)
    pbar.close()

# --- config: derive repo root and load deploy.json ----------------------------
ROOT = Path(__file__).resolve().parents[2]

ROOT_CONFIG = ROOT / "deploy.json"
VSCODE_CONFIG = ROOT / ".vscode/deploy.json"

config = {
    "git_src": str(ROOT),
}

cfg_path = None
if ROOT_CONFIG.exists():
    cfg_path = ROOT_CONFIG
elif VSCODE_CONFIG.exists():
    cfg_path = VSCODE_CONFIG
else:
    print("[ERROR] No deploy.json found in git root or .vscode/")
    sys.exit(1)

# NEW: Debug which base config file we are using
print(f"[CONFIG] Using base config file: {cfg_path}")

try:
    with open(cfg_path, "r") as f:
        user_cfg = json.load(f)
    if not isinstance(user_cfg, dict):
        raise ValueError("Config JSON must contain an object at the top level.")
    config.update(user_cfg)
except Exception as e:
    print(f"[ERROR] Failed to load config: {e}")
    sys.exit(1)

if "tgt_name" not in config or not config["tgt_name"]:
    print(f"[ERROR] Missing 'tgt_name' in {cfg_path}. Aborting.")
    sys.exit(1)

CONFIG_PATH = str(cfg_path)

pbar = None

# === Ethos Serial + Serial Tail helpers =======================================

DEFAULT_SERIAL_VID = "0483"
DEFAULT_SERIAL_PID = "5750"
DEFAULT_SERIAL_BAUD = 115200
DEFAULT_SERIAL_RETRIES = 10
DEFAULT_SERIAL_DELAY = 1.0

def ethos_serial(ethossuite_bin, action, radio=None):
    cmd = [ethossuite_bin, "--serial", action, "--radio", "auto"]
    if radio:
        cmd += ["--radio", radio]
    try:
        res = subprocess.run(cmd, text=True, capture_output=True, timeout=20)
        out = (res.stdout or "").strip()
        err = (res.stderr or "").strip()
        if out:
            print(out)
        if err:
            print(err)
        return res.returncode, out, err
    except Exception as e:
        print(f"[ETHOS] --serial {action} failed: {e}")
        return 1, "", str(e)


def wait_for_scripts_mount(ethossuite_bin, attempts=10, delay=2):
    """
    Poll Ethos Suite for the mounted SCRIPTS directory.

    Behaviour:
      - Try Ethos Suite up to `attempts` times.
      - If still not mounted, perform a final USB drive scan fallback.
    Debug:
      - Set DEPLOY_DEBUG_MOUNT=1 to print the returned path / exception each attempt.
    """
    debug_mount = os.environ.get("DEPLOY_DEBUG_MOUNT", "").strip().lower() in ("1", "true", "yes", "on")

    last_err = None
    last_path = None

    for i in range(attempts):
        try:
            path = get_ethos_scripts_dir(ethossuite_bin, retries=0, delay=delay)
            last_path = path
            if debug_mount:
                print(f"[ETHOS][DEBUG] get_ethos_scripts_dir -> {path!r}")
            if path and os.path.isdir(path):
                mounted = os.path.normpath(path)
                print(f"[ETHOS] Radio drive mounted: {mounted}")
                return mounted
            raise RuntimeError(f"Ethos returned non-directory path: {path!r}")
        except Exception as e:
            last_err = e
            if debug_mount:
                print(f"[ETHOS][DEBUG] attempt {i+1}/{attempts} failed: {type(e).__name__}: {e}")
            print(f"[ETHOS] Waiting for radio drive ({i+1}/{attempts})…")
            time.sleep(delay)

    # Final fallback: explicit USB scan (only after Ethos Suite polling is exhausted)
    print("[ETHOS] Ethos Suite polling exhausted; attempting USB drive scan fallback…")
    fb = None
    try:
        fb = scan_usb_drives_for_radio()
    except Exception as e:
        if debug_mount:
            print(f"[ETHOS][DEBUG] scan_usb_drives_for_radio crashed: {type(e).__name__}: {e}")

    if fb and os.path.isdir(fb):
        fb = os.path.normpath(fb)
        print(f"[ETHOS] USB scan fallback found radio: {fb}")
        return fb

    raise RuntimeError(f"Radio drive did not mount (last_path={last_path!r}): {last_err}")
def _find_com_port_by_vid_pid(vid_hex, pid_hex):
    try:
        from serial.tools import list_ports
    except Exception as e:
        print("[SERIAL] pyserial not installed. Install with: pip install pyserial")
        return None


def _find_com_port(vid_hex=None, pid_hex=None, name_hint=None, allow_fuzzy_if_no_vidpid=True, prefer_pid_from_hwid=True):
    try:
        from serial.tools import list_ports
    except Exception:
        print("[SERIAL] pyserial not installed. Install with: pip install pyserial")
        return None

    ports = list(list_ports.comports())
    if not ports:
        print("[SERIAL] No serial ports detected.")
        return None

    print("[SERIAL] Detected ports:")
    for p in ports:
        desc = p.description or ''
        iface = getattr(p, 'interface', None) or ''
        print(f"  - device={p.device} vid={p.vid} pid={p.pid} desc='{desc}' iface='{iface}' hwid='{p.hwid}'")

    def _pid_from_hwid(hw):
        try:
            hw = hw or ""
            token = "PID="
            if token in hw:
                rhs = hw.split(token, 1)[1]
                pid_str = rhs.split(":")[1].split()[0]
                return int(pid_str, 16)
        except Exception:
            pass
        return None

    if vid_hex and pid_hex:
        try:
            vid = int(vid_hex, 16)
            pid = int(pid_hex, 16)
        except Exception:
            vid = pid = None
        if vid is not None and pid is not None:
            for p in ports:
                try:
                    if p.vid == vid and p.pid == pid:
                        return p.device
                except Exception:
                    pass
            print(f"[SERIAL] No exact VID:PID match yet ({vid_hex}:{pid_hex}). Will keep scanning.")
            return None

    if vid_hex and not pid_hex:
        try:
            vid = int(vid_hex, 16)
        except Exception:
            vid = None
        candidates = []
        for p in ports:
            try:
                if p.vid == vid:
                    candidates.append(p)
            except Exception:
                pass
        if candidates:
            def _score(cp):
                cp_pid = getattr(cp, "pid", None)
                hw_pid = _pid_from_hwid(getattr(cp, "hwid", None)) if prefer_pid_from_hwid else None
                pid_val = cp_pid if cp_pid is not None else hw_pid
                if pid_val == 0x5750: return 0
                if pid_val == 0x5740: return 2
                return 1
            best = sorted(candidates, key=_score)[0]
            return best.device

    if allow_fuzzy_if_no_vidpid and not vid_hex and not pid_hex:
        hints = [h.lower() for h in [name_hint, "frsky", "serial", "stm", "vcp", "x20", "x18", "x14"] if h]
        for p in ports:
            desc = f"{p.description or ''} {getattr(p,'interface','') or ''}".lower()
            if any(h in desc for h in hints):
                return p.device

    return None


def tail_serial_debug(vid=DEFAULT_SERIAL_VID, pid=DEFAULT_SERIAL_PID,
                      baud=DEFAULT_SERIAL_BAUD, retries=DEFAULT_SERIAL_RETRIES,
                      delay=DEFAULT_SERIAL_DELAY, newline=b'\n', name_hint="Serial"):
    try:
        import serial
    except Exception:
        print("[SERIAL] pyserial not installed. Install with: pip install pyserial")
        return 2

    time.sleep(1.5)

    port = None
    for i in range(retries):
        port = _find_com_port(vid_hex=vid, pid_hex=pid, name_hint=name_hint,
                              allow_fuzzy_if_no_vidpid=False)
        if port:
            break
        print(f"[SERIAL] Waiting for COM port ({i+1}/{retries})…")
        time.sleep(delay)

    if not port:
        print("[SERIAL] No suitable COM port found. See the detected ports above.")
        return 3

    print(f"[SERIAL] Connecting to {port} @ {baud} …")
    open_attempts = 8
    for attempt in range(1, open_attempts+1):
        try:
            s = serial.Serial(port=port, baudrate=baud, timeout=0.5)
            break
        except FileNotFoundError as e:
            print(f"[SERIAL] Open attempt {attempt}/{open_attempts} -> device vanished; rescanning…")
            port = _find_com_port(vid_hex=vid, pid_hex=pid, name_hint=name_hint)
            if not port:
                import time as _t; _t.sleep(delay)
            continue
        except Exception as e:
            print(f"[SERIAL] Open attempt {attempt}/{open_attempts} failed: {e}")
            import time as _t; _t.sleep(delay)
            continue
    else:
        print("[SERIAL] Could not open any matching COM port after multiple attempts.")
        return 4

    try:
        with s:
            print("- Serial connected. Press Ctrl+C to stop -")
            buf = b""
            while True:
                try:
                    data = s.read(1024)
                    if data:
                        buf += data
                        while True:
                            if newline in buf:
                                line, buf = buf.split(newline, 1)
                                try:
                                    print(line.decode('utf-8', errors='replace'))
                                except Exception:
                                    print(line)
                            else:
                                break
                except KeyboardInterrupt:
                    print("[SERIAL] Stopped by user.")
                    return 0
    except KeyboardInterrupt:
        print("[SERIAL] Stopped by user.")
        return 0
    except Exception as e:
        print(f"[SERIAL] Error: {e}")
        return 4

# Copy with progress
def copy_verbose(src, dst):
    pbar.update(1)
    if DEPLOY_TO_RADIO:
        throttled_copyfile(src, dst)
        flush_fs()
        time.sleep(0.05)
    else:
        shutil.copy(src, dst)


def count_files(dirpath, ext=None):
    total = 0
    for _, _, files in os.walk(dirpath):
        if ext:
            files = [f for f in files if f.endswith(ext)]
        total += len(files)
    return total

def run_step_script(step, out_dir, lang="en"):
    """
    Generic step runner.

    Conventions:
      - If `step` ends with '.py' or contains a path separator,
          treat it as a path (absolute or relative to git_src).
      - Otherwise, look for:
          <git_src>/.vscode/scripts/deploy_step_<step>.py
    The step script is called as:
      python <script> --out-dir OUT --lang LANG --git-src GIT_SRC
    """
    git_src = config["git_src"]

    # Determine script path
    if step.endswith(".py") or os.sep in step or "/" in step:
        script_path = step
        if not os.path.isabs(script_path):
            script_path = os.path.join(git_src, script_path)
    else:
        script_path = os.path.join(
            git_src, ".vscode", "scripts", f"deploy_step_{step}.py"
        )

    script_path = os.path.normpath(script_path)

    if not os.path.isfile(script_path):
        print(f"[STEP] Skipping '{step}': script not found at {script_path}")
        return

    cmd = [
        sys.executable,
        script_path,
        "--out-dir", out_dir,
        "--lang", lang,
        "--git-src", git_src,
    ]

    print(f"[STEP] Running '{step}' → {script_path}")
    try:
        subprocess.run(cmd, check=True)
    except subprocess.CalledProcessError as e:
        print(f"[STEP] Step '{step}' failed with exit code {e.returncode}")
    except Exception as e:
        print(f"[STEP] Step '{step}' crashed: {e}")


def run_steps(steps, out_dir, lang="en"):
    """Run all requested steps (if any) for this output directory."""
    if not steps:
        return
    for step in steps:
        run_step_script(step, out_dir, lang=lang)



def copy_files(src_override, fileext, targets, lang="en", steps=None):
    global pbar
    git_src = src_override or config['git_src']
    tgt = config['tgt_name']
    print(f"Copy mode: {fileext or 'all'}")

    for i, t in enumerate(targets, 1):
        dest = t['dest']; sim = t.get('simulator')
        print(f"[{i}/{len(targets)}] -> {t['name']} @ {dest}")

        if not os.path.isdir(dest):
            fallback = os.path.normpath(os.path.join(git_src, 'simulator', 'scripts'))
            try:
                os.makedirs(fallback, exist_ok=True)
                print(f"[DEST] '{dest}' not found. Using fallback: {fallback}")
                t['dest'] = fallback
                dest = fallback
            except Exception as e:
                print(f"[DEST ERROR] Could not create fallback folder at {fallback}: {e}")
                raise
        out_dir = os.path.join(dest, tgt)

        if fileext == '.lua':
            if os.path.isdir(out_dir):
                for r, _, files in os.walk(out_dir):
                    for f in files:
                        if f.endswith(('.lua','.luac')):
                            os.remove(os.path.join(r,f))
            scr = os.path.join(git_src, 'src', tgt)
            os.makedirs(out_dir, exist_ok=True)
            for r,_,files in os.walk(scr):
                for f in files:
                    if f.endswith('.lua'):
                        shutil.copy(os.path.join(r,f), out_dir)

            run_steps(steps, out_dir, lang)

        elif fileext == 'fast':
            scr = os.path.join(git_src, 'src', tgt)

            if os.path.isdir(out_dir):
                removed = 0
                for r, _, files in os.walk(out_dir):
                    for f in files:
                        if f.endswith('.luac'):
                            try:
                                os.remove(os.path.join(r, f))
                                removed += 1
                            except Exception as e:
                                print(f"[WARN] Failed to delete {f}: {e}")
                if removed:
                    print(f"Fast deploy cleanup: removed {removed} stale .luac file(s).")

            TS_SLACK = 2.0

            files_all = []
            for r, _, files in os.walk(scr):
                for f in files:
                    srcf = os.path.join(r, f)
                    rel  = os.path.relpath(srcf, scr)
                    dstf = os.path.join(out_dir, rel)
                    files_all.append((srcf, dstf, rel))

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

            to_copy = []
            if files_all:
                bar_verify = tqdm(total=len(files_all), desc="Verifying (MD5)")
                for srcf, dstf, rel in files_all:
                    os.makedirs(os.path.dirname(dstf), exist_ok=True)
                    if needs_copy_with_md5(srcf, dstf):
                        to_copy.append((srcf, dstf, rel))
                    bar_verify.update(1)
                bar_verify.close()

            copied = 0
            if to_copy:
                bar_update = tqdm(total=len(to_copy), desc="Updating files")
                for srcf, dstf, rel in to_copy:
                    if DEPLOY_TO_RADIO:
                        throttled_copyfile(srcf, dstf)
                        flush_fs()
                        time.sleep(0.05)
                    else:
                        shutil.copy(srcf, dstf)
                    if not rel.replace("\\","/").endswith("tasks/logger/init.lua"):
                        print(f"Copy {rel}")
                    copied += 1
                    bar_update.update(1)
                bar_update.close()

            run_steps(steps, out_dir, lang)

            if not copied:
                print("Fast deploy: nothing to update.")

        else:
            srcall = os.path.join(git_src, 'src', tgt)
            safe_full_copy(srcall, out_dir)
            run_steps(steps, out_dir, lang)
            flush_fs()
            time.sleep(2)

            print(f"Done: {t['name']}\n")


def patch_logger_init(out_root):
    import os, re
    target_file = os.path.join(out_root, 'tasks', 'logger', 'init.lua')
    try:
        if not os.path.exists(target_file):
            print(f"[PATCH] logger init.lua not found: {target_file}")
            return

        with open(target_file, 'r', encoding='utf-8', errors='replace') as f:
            lines = f.readlines()

        changed = 0
        key_re = re.compile(
            r'(?i)^(?P<indent>\s*)'
            r'(?P<key>(?:\[\s*["\']simulatoronly["\']\s*\]|simulatoronly))'
            r'(?P<between>\s*=\s*)'
            r'(?P<val>true)'
            r'(?P<after>\s*,?)'
        )

        for i, line in enumerate(lines):
            code, sep, comment = line.partition('--')
            m = key_re.search(code)
            if m:
                code = (
                    code[:m.start()] +
                    f"{m.group('indent')}{m.group('key')}{m.group('between')}false{m.group('after')}" +
                    code[m.end():]
                )
                lines[i] = code + (sep + comment if sep else '')
                changed += 1

        if changed:
            with open(target_file, 'w', encoding='utf-8', newline='') as f:
                f.writelines(lines)
            print(f"[PATCH] Set simulatoronly=false in {target_file} ({changed} change{'s' if changed!=1 else ''}).")
        else:
            print(f"[PATCH] No changes needed for {target_file} (already false or key missing).")
    except Exception as e:
        print(f"[PATCH] Failed to edit {target_file}: {e}")


def launch_sims(targets):
    for t in targets:
        sim = t.get('simulator')
        if sim:
            print(f"Launching {t['name']}: {sim}")
            out = subprocess_conout.subprocess_conout(sim, nrows=9999, encode=True)
            print(out)


def main():
    global DEPLOY_TO_RADIO
    p = argparse.ArgumentParser(description='Deploy & launch')
    p.add_argument(
        '--config',
        default=CONFIG_PATH,
        help='Optional path to a JSON config file (Ethos/serial settings).'
    )
    p.add_argument('--src')
    p.add_argument('--fileext')
    p.add_argument('--all', action='store_true')
    p.add_argument('--launch', action='store_true')
    p.add_argument('--radio', action='store_true')
    p.add_argument('--radio-debug', action='store_true')
    p.add_argument('--connect-only', action='store_true')
    p.add_argument('--lang', default=os.environ.get("RFSUITE_LANG", "en"),
                   help='Locale to resolve (e.g. en, de, fr). Defaults to env RFSUITE_LANG or "en".')
    p.add_argument('--force', action='store_true',
                   help='Take over a stale single-instance lock if the previous run crashed.')
    p.add_argument('--clear-lock', action='store_true',
                   help='Delete ONLY the current project lock and exit.')
    p.add_argument('--clear-all-locks', action='store_true',
                   help='Delete ALL deploy-*.lock files in the system temp and exit.')
    p.add_argument('--print-lock', action='store_true',
                   help='Print the lock file path for this project and exit.')
    p.add_argument('--step', dest='steps', action='append',
                   help='Additional deploy steps to run (e.g. i18n, soundpack). '
                        'Can be given multiple times.'
    )    

    args = p.parse_args()
    DEPLOY_TO_RADIO = args.radio

    DEPLOY_PIDFILE = os.path.join(tempfile.gettempdir(), "deploy-copy.pid")
    try:
        with open(DEPLOY_PIDFILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass
    atexit.register(lambda: os.path.exists(DEPLOY_PIDFILE) and os.remove(DEPLOY_PIDFILE))

    if args.config and os.path.abspath(args.config) != os.path.abspath(CONFIG_PATH) and os.path.exists(args.config):
        try:
            with open(args.config) as f:
                override_cfg = json.load(f)
            if isinstance(override_cfg, dict):
                config.update(override_cfg)
                # NEW: Debug which override config file is loaded
                print(f"[CONFIG] Loaded override config file: {os.path.abspath(args.config)}")
            else:
                print(f"[CONFIG WARN] Override config at {args.config} is not a JSON object; ignoring.")
        except json.JSONDecodeError as e:
            print(f"[CONFIG WARN] Failed to parse override JSON config file at {args.config}: {e}")

    # NEW: Always show the effective config source used for locks & overrides
    print(f"[CONFIG] Effective config source (for locks & overrides): {os.path.abspath(args.config)}")

    if args.print_lock:
        print(_lock_path_for_config(args.config))
        return 0

    if args.clear_all_locks:
        tmp = tempfile.gettempdir()
        removed = 0
        for f in glob(os.path.join(tmp, "deploy-*.lock")):
            try:
                os.remove(f)
                print(f"Removed: {f}")
                removed += 1
            except Exception as e:
                print(f"Could not remove: {f} — {e}", file=sys.stderr)
        print(f"Removed {removed} lock file(s) from {tmp}")
        return 0

    if args.clear_lock:
        path = _lock_path_for_config(args.config)
        try:
            os.remove(path)
            print(f"Removed: {path}")
            return 0
        except FileNotFoundError:
            print(f"No lock found: {path}")
            return 0
        except Exception as e:
            print(f"Could not remove: {path} — {e}", file=sys.stderr)
            return 1

    proj_key = md5(os.path.abspath(args.config).encode("utf-8")).hexdigest()[:8]
    lock_name = f"deploy-{proj_key}.lock"
    try:
        SingleInstance(name=lock_name, force=args.force).acquire()
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        return 1

    ethos_bin = config.get('ethossuite_bin')
    if ethos_bin and not check_ethossuite_version(ethos_bin, min_version=MIN_ETHOSSUITE_VERSION):
        sys.exit(1)

    # --- target selection: RADIO vs SIMULATOR ---------------------------------
    targets = []

    if args.radio and args.connect_only:
        # Just enable serial & tail logs; no copying
        ethos_serial(config['ethossuite_bin'], 'start')

        v = str(config.get('serial_vid', DEFAULT_SERIAL_VID))
        p = str(config.get('serial_pid', DEFAULT_SERIAL_PID))
        b = int(config.get('serial_baud', DEFAULT_SERIAL_BAUD))
        r = int(config.get('serial_retries', DEFAULT_SERIAL_RETRIES))
        d = float(config.get('serial_retry_delay', DEFAULT_SERIAL_DELAY))
        nh = str(config.get('serial_name_hint', "Serial"))

        return tail_serial_debug(vid=v, pid=p, baud=b, retries=r, delay=d, name_hint=nh)

    if args.radio and not args.connect_only:
        # RADIO DEPLOY: use Ethos Suite to locate the radio SCRIPTS path
        print("[ETHOS] Disabling serial debug before copy to protect filesystem…")
        ethos_serial(config['ethossuite_bin'], 'stop')
        try:
            rd = wait_for_scripts_mount(config['ethossuite_bin'], attempts=10, delay=2)
        except Exception as e:
            print("[ERROR] Failed to obtain Ethos SCRIPTS path after disabling serial.")
            print(f"        Reason: {e}")
            try:
                import winsound
                winsound.MessageBeep()
            except Exception:
                print("\a", end="", flush=True)
            return 1

        targets = [{'name': 'Radio', 'dest': rd, 'simulator': None}]
    else:
        # SIMULATOR DEPLOY: always to <git_src>\simulator\[firmware]\scripts
        firmware = os.environ.get("ETHOS_FIRMWARE")
        path_parts = [config['git_src'], 'simulator']
        if firmware:
            path_parts.append(firmware)
        path_parts.append('scripts')

        fixed_dest = os.path.normpath(os.path.join(*path_parts))
        os.makedirs(fixed_dest, exist_ok=True)
        targets = [{'name': 'Simulator', 'dest': fixed_dest, 'simulator': None}]

    # -------------------------------------------------------------------------
    copy_files(args.src, args.fileext, targets, lang=args.lang, steps=args.steps)

    if args.launch and not args.radio:
        launch_sims(targets)

    if args.radio and not args.radio_debug:
        ethos_serial(config['ethossuite_bin'], 'start')

    if args.radio and args.radio_debug:
        _kill_previous_tail_if_any()
        rc, _, _ = ethos_serial(config['ethossuite_bin'], 'start')
        if rc != 0:
            print("[ETHOS] First --serial start failed; retrying once…")
            ethos_serial(config['ethossuite_bin'], 'start')

        v = str(config.get('serial_vid', DEFAULT_SERIAL_VID))
        p = str(config.get('serial_pid', DEFAULT_SERIAL_PID))
        b = int(config.get('serial_baud', DEFAULT_SERIAL_BAUD))
        r = int(config.get('serial_retries', DEFAULT_SERIAL_RETRIES))
        d = float(config.get('serial_retry_delay', DEFAULT_SERIAL_DELAY))
        nh = str(config.get('serial_name_hint', "Serial"))

        tail_serial_debug(vid=v, pid=p, baud=b, retries=r, delay=d, name_hint=nh)

if __name__ == '__main__':
    rc = main()
    try:
        sys.exit(rc if isinstance(rc, int) else 0)
    except SystemExit:
        pass
