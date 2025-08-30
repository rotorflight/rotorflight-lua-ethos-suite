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

SERIAL_PIDFILE = os.path.join(tempfile.gettempdir(), "rfdeploy-serial.pid")
DEPLOY_TO_RADIO = False  # flag to control radio-only behavior
THROTTLE_EXTS = None  # unused when throttling all copies
THROTTLE_MIN_BYTES = 0  # unused when throttling all copies
THROTTLE_CHUNK = 16 * 1024          # 16 KiB
THROTTLE_PAUSE_EVERY = 64 * 1024  # pause+fsync every 64 KiB written
THROTTLE_PAUSE_S = 0.2             # 200 ms

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
    # raw (unbuffered) file handles so we control write cadence precisely
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

        # final drain
        fdst.flush()
        try:
            os.fsync(fdst.fileno())
        except OSError:
            pass

    # Match shutil.copy's behavior of preserving basic permission bits
    try:
        shutil.copymode(src, dst)
    except Exception:
        pass



def minify_lua_file(filepath):
    print(f"[MINIFY] (luamin) Processing: {filepath}")

    # Try to resolve luamin executable
    luamin_cmd = shutil.which("luamin")

    if not luamin_cmd:
        # Fallback for Windows NPM global installs
        luamin_cmd = os.path.expandvars(r"%APPDATA%\\npm\\luamin.cmd")

        if not os.path.exists(luamin_cmd):
            print("[MINIFY ERROR] 'luamin' not found in PATH or %APPDATA%\\npm.")
            print("Please run: npm install -g luamin")
            return

    try:
        result = subprocess.run(
            [luamin_cmd, '-f', filepath],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding='utf-8',  # ✅ force proper decoding
            errors='replace'   # ✅ optional: replace invalid chars to avoid crash
        )

        if result.returncode != 0:
            print(f"[MINIFY ERROR] Failed to minify {filepath}:\n{result.stderr}")
            return

        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(result.stdout)

        #print(f"[MINIFY] (luamin) Done: {filepath}")

    except Exception as e:
        print(f"[MINIFY ERROR] Exception during luamin run: {e}")

def get_ethos_scripts_dir(ethossuite_bin, retries=1, delay=5):
    """
    Ask Ethos Suite for the SCRIPTS path. Robust against chatty output:
    - Prefer explicit path lines (e.g. 'E:\\scripts')
    - Else parse the 'New removable disks: [...]' blob and use mountpoint + '\\scripts'
    - Else fall back to scanning drive letters for an existing '\\scripts'
    """
    import re, json, string

    cmd = [ethossuite_bin, "--get-path", "SCRIPTS", "--radio", "auto"]
    path_re = re.compile(r'^(?:[A-Za-z]:\\|\\\\\?\\|//)[^\r\n]+$')

    def _clean(line: str) -> str:
        line = (line or "").strip().strip('"').strip("'")
        if not line: return ""
        low = line.lower()
        if low.startswith("exit code"): return ""
        if low.startswith("new removable disks"): return line  # keep for JSON parse
        if line.startswith("{") or line.startswith("["): return line
        return line

    def _scan_drives_for_scripts():
        for letter in string.ascii_uppercase:
            root = f"{letter}:\\scripts"
            try:
                if os.path.isdir(root):
                    return os.path.normpath(root)
            except Exception:
                pass
        return None

    last_err = None
    for attempt in range(retries + 1):
        try:
            res = subprocess.run(cmd, text=True, capture_output=True, timeout=20)
            if res.returncode != 0:
                raise subprocess.CalledProcessError(res.returncode, cmd, output=res.stdout, stderr=res.stderr)

            raw = res.stdout or ""
            lines = [_clean(l) for l in raw.splitlines() if l.strip()]
            # 1) Prefer explicit path-like lines
            candidates = [l for l in lines if path_re.match(l)]
            existing = [os.path.normpath(p) for p in candidates if os.path.isdir(os.path.normpath(p))]
            if existing:
                # Prefer the one whose basename is 'scripts'
                preferred = [p for p in existing if os.path.basename(p).lower() == "scripts"]
                return preferred[0] if preferred else existing[0]
            if candidates:
                # If nothing exists yet, return the most plausible; wait_for_scripts_mount() will verify
                preferred = [p for p in candidates if "scripts" in p.lower()]
                return os.path.normpath(preferred[0] if preferred else candidates[0])

            # 2) Parse the "New removable disks:  [...]" blob if present
            blob_lines = [l for l in lines if l.lower().startswith("new removable disks")]
            if blob_lines:
                # Extract JSON array portion (first '[' ... last ']')
                blob = blob_lines[-1]
                try:
                    start = blob.index('['); end = blob.rindex(']') + 1
                    arr = json.loads(blob[start:end])
                    # Prefer the entry with radioDisk == 'radio', else first that has a mountpoint
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

            # 3) Last resort: scan mounted drive letters for an existing \scripts
            scanned = _scan_drives_for_scripts()
            if scanned:
                return scanned

            # No usable hint; let caller retry
            raise RuntimeError("No path-like output from Ethos Suite; mount not ready yet.")
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired, RuntimeError) as e:
            last_err = e
            if attempt < retries:
                print(f"[ETHOS] Could not get SCRIPTS path (attempt {attempt+1}/{retries+1}). Retrying in {delay}s…")
                time.sleep(delay)
            else:
                raise last_err

    """
    Ask Ethos Suite for the SCRIPTS path. Returns a normalized existing path.
    Skips noisy lines like "New removable disks: [...]".
    """
    import re

    cmd = [ethossuite_bin, "--get-path", "SCRIPTS", "--radio", "auto"]
    path_re = re.compile(r'^(?:[A-Za-z]:\\|\\\\\?\\|//)[^\r\n]+$')  # Windows drive, \\?\ or UNC

    def _clean(line: str) -> str:
        # Strip quotes and whitespace
        line = line.strip().strip('"').strip("'")
        # Ignore obvious noise
        if not line:
            return ""
        if line.lower().startswith("exit code"):
            return ""
        if line.lower().startswith("new removable disks"):
            return ""
        if line.startswith("{") or line.startswith("["):
            return ""
        return line

    last_err = None
    for attempt in range(retries + 1):
        try:
            res = subprocess.run(cmd, text=True, capture_output=True, timeout=15)
            if res.returncode != 0:
                raise subprocess.CalledProcessError(res.returncode, cmd, output=res.stdout, stderr=res.stderr)

            raw_lines = (res.stdout or "").splitlines()
            # Clean and filter
            candidates = []
            for l in raw_lines:
                c = _clean(l)
                if not c:
                    continue
                # Prefer things that look like paths, ideally ending with "scripts"
                if path_re.match(c):
                    candidates.append(c)

            # Heuristics: prefer existing paths, then those that contain \scripts
            existing = [os.path.normpath(p) for p in candidates if os.path.isdir(os.path.normpath(p))]
            if existing:
                # If multiple, prefer one whose basename is 'scripts'
                preferred = [p for p in existing if os.path.basename(p).lower() == "scripts"]
                return preferred[0] if preferred else existing[0]

            # If nothing exists yet, still try best-looking candidate (may mount a moment later)
            if candidates:
                # Prefer entries that contain 'scripts'
                preferred = [p for p in candidates if "scripts" in p.lower()]
                return os.path.normpath(preferred[0] if preferred else candidates[0])

            # No usable line; fall through to retry
            raise RuntimeError("No path-like output from Ethos Suite.")

        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired, RuntimeError) as e:
            last_err = e
            if attempt < retries:
                print(f"[ETHOS] Could not get SCRIPTS path (attempt {attempt+1}/{retries+1}). Retrying in {delay}s…")
                time.sleep(delay)
            else:
                raise last_err


    """
    Ask Ethos Suite for the SCRIPTS path. Retries after `delay` seconds
    if the tool returns no path or fails. Raises on final failure.
    """
    cmd = [ethossuite_bin, "--get-path", "SCRIPTS", "--radio", "auto"]
    last_err = None

    for attempt in range(retries + 1):
        try:
            result = subprocess.run(
                cmd,
                text=True,
                capture_output=True,
                timeout=15
            )

            if result.returncode != 0:
                raise subprocess.CalledProcessError(
                    result.returncode, cmd, output=result.stdout, stderr=result.stderr
                )

            lines = [l.strip() for l in (result.stdout or "").splitlines() if l.strip()]
            if not lines:
                raise RuntimeError("No output from Ethos Suite.")

            # If the last line starts with 'exit code', grab the previous one
            if lines[-1].lower().startswith("exit code") and len(lines) >= 2:
                path_line = lines[-2]
            else:
                path_line = lines[-1]

            return os.path.normpath(path_line)

        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired, RuntimeError) as e:
            last_err = e
            if attempt < retries:
                print(f"[ETHOS] Could not get SCRIPTS path (attempt {attempt+1}/{retries+1}). Retrying in {delay}s…")
                time.sleep(delay)
            else:
                raise last_err
            
# Permission handler for Windows rm errors
def on_rm_error(func, path, exc_info):
    """Resilient rm error handler:
    - ignore if the path vanished
    - chmod + retry with small backoff for common transient Windows errors
    """
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
            # 5=Access denied, 32=Sharing violation, 483=Fatal device hw error
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


# Throttled, progress-bar deletion to play nice with slow devices
DELETE_BATCH = 1
DELETE_PAUSE_S = 0.10  # 100ms

def throttled_rmtree(root, batch=DELETE_BATCH, pause=DELETE_PAUSE_S):
    if not os.path.exists(root):
        return
    # Collect files for a stable progress bar
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
                # Give up on odd errors rather than crash the whole deploy
                # (old file may be locked by AV or indexing; we'll try removing the directory later)
                break

        bar.update(1)
        if i % batch == 0:
            flush_fs()
            time.sleep(pause)

    bar.close()

    # Remove directories bottom-up; ignore stubborn remnants
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
    """Safer full-copy for slow FAT32 targets:
    - If current target exists, rotate it to '<target>.old'
    - Delete the '<target>.old' folder
    - Copy new files freshly into '<target>'
    Includes small delays + best-effort flushes to give the device time to settle.
    """
    global pbar
    if os.path.isdir(out_dir):
        old_dir = out_dir + ".old"

        # If a previous backup exists, remove it first
        if os.path.isdir(old_dir):
            print("Deleting previous backup…")
            delete_tree(old_dir)
            flush_fs()
            time.sleep(2)

        # Rotate current folder to .old
        try:
            print(f"Renaming existing to {os.path.basename(old_dir)}…")
            os.replace(out_dir, old_dir)  # Atomic on same volume
        except Exception as e:
            print(f"[WARN] Rename failed ({e}). Falling back to direct delete.")
            print("Deleting files…")
            delete_tree(out_dir)
        flush_fs()
        time.sleep(2)

        # Delete the rotated .old folder
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
# Load config from environment variable only
CONFIG_PATH = os.environ.get('RFSUITE_CONFIG')

if not CONFIG_PATH:
    print("[CONFIG ERROR] Environment variable RFSUITE_CONFIG is not set.")
    sys.exit(1)

if not os.path.exists(CONFIG_PATH):
    print(f"[CONFIG ERROR] Config file not found at path: {CONFIG_PATH}")
    sys.exit(1)

try:
    with open(CONFIG_PATH) as f:
        config = json.load(f)
except json.JSONDecodeError as e:
    print(f"[CONFIG ERROR] Failed to parse JSON config file: {e}")
    sys.exit(1)


pbar = None


# === Ethos Serial + Serial Tail helpers =======================================

DEFAULT_SERIAL_VID = "0483"  # STM32 VCP / HID used by FrSky radios in Ethos logs
DEFAULT_SERIAL_PID = "5750"
DEFAULT_SERIAL_BAUD = 115200
DEFAULT_SERIAL_RETRIES = 10
DEFAULT_SERIAL_DELAY = 1.0    # seconds between attempts

def ethos_serial(ethossuite_bin, action, radio=None):
    """
    Start/stop Ethos serial debug mode.
    action: 'start' or 'stop'
    Returns (rc, stdout, stderr) and prints tool output.
    """
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
    Poll Ethos for the SCRIPTS path until the directory actually exists.
    """
    last_err = None
    for i in range(attempts):
        try:
            path = get_ethos_scripts_dir(ethossuite_bin, retries=0, delay=delay)
            if path and os.path.isdir(path):
                return os.path.normpath(path)
            raise RuntimeError(f"Ethos returned non-directory path: {path!r}")
        except Exception as e:
            last_err = e
            print(f"[ETHOS] Waiting for radio drive ({i+1}/{attempts})…")
            time.sleep(delay)
    raise RuntimeError(f"Radio drive did not mount: {last_err}")




def _find_com_port_by_vid_pid(vid_hex, pid_hex):
    try:
        from serial.tools import list_ports
    except Exception as e:
        print("[SERIAL] pyserial not installed. Install with: pip install pyserial")
        return None


def _find_com_port(vid_hex=None, pid_hex=None, name_hint=None):
    try:
        from serial.tools import list_ports
    except Exception:
        print("[SERIAL] pyserial not installed. Install with: pip install pyserial")
        return None

    ports = list(list_ports.comports())
    if not ports:
        print("[SERIAL] No serial ports detected.")
        return None

    # Debug dump so you can see what's actually present
    print("[SERIAL] Detected ports:")
    for p in ports:
        desc = p.description or ''
        iface = getattr(p, 'interface', None) or ''
        print(f"  - device={p.device} vid={p.vid} pid={p.pid} desc='{desc}' iface='{iface}' hwid='{p.hwid}'")

    # 1) Strict VID/PID match if provided
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

    # 2) Fallback: fuzzy name/description match (e.g. contains 'Serial' or 'FrSky')
    hints = [h.lower() for h in [name_hint, "frsky", "serial", "stm", "vcp", "x20", "x18", "x14"] if h]
    for p in ports:
        desc = f"{p.description or ''} {getattr(p,'interface','') or ''}".lower()
        if any(h in desc for h in hints):
            return p.device

    return None

    vid = int(vid_hex, 16)
    pid = int(pid_hex, 16)
    for p in list_ports.comports():
        try:
            if p.vid == vid and p.pid == pid:
                return p.device  # e.g. 'COM7'
        except Exception:
            continue
    return None


def tail_serial_debug(vid=DEFAULT_SERIAL_VID, pid=DEFAULT_SERIAL_PID,
                      baud=DEFAULT_SERIAL_BAUD, retries=DEFAULT_SERIAL_RETRIES,
                      delay=DEFAULT_SERIAL_DELAY, newline=b'\n', name_hint="Serial"):
    "Try to attach to the radio serial log N times; print lines until Ctrl+C."
    try:
        import serial
    except Exception:
        print("[SERIAL] pyserial not installed. Install with: pip install pyserial")
        return 2

    # Give Windows a moment to enumerate after enabling serial
    time.sleep(1.5)

    port = None
    for i in range(retries):
        # Prefer strict VID/PID match, then fallback to name hint
        port = _find_com_port(vid_hex=vid, pid_hex=pid, name_hint=name_hint)
        if port:
            break
        print(f"[SERIAL] Waiting for COM port ({i+1}/{retries})…")
        time.sleep(delay)

    if not port:
        print("[SERIAL] No suitable COM port found. See the detected ports above.")
        return 3

    print(f"[SERIAL] Connecting to {port} @ {baud} …")
    # Some Windows setups expose the COM device and then rebind the driver briefly.
    # Try multiple times to open the port before giving up; if it disappears, rescan.
    open_attempts = 8
    for attempt in range(1, open_attempts+1):
        try:
            s = serial.Serial(port=port, baudrate=baud, timeout=0.5)
            break
        except FileNotFoundError as e:
            print(f"[SERIAL] Open attempt {attempt}/{open_attempts} -> device vanished; rescanning…")
            # Rescan for a replacement port that matches
            port = _find_com_port(vid_hex=vid, pid_hex=pid, name_hint=name_hint)
            if not port:
                import time as _t; _t.sleep(delay)
            continue
        except Exception as e:
            # e.g. PermissionError / SerialException("Access is denied"), or still binding
            print(f"[SERIAL] Open attempt {attempt}/{open_attempts} failed: {e}")
            import time as _t; _t.sleep(delay)
            continue
    else:
        print("[SERIAL] Could not open any matching COM port after multiple attempts.")
        return 4

    try:
        with s:
            print("— Serial connected. Press Ctrl+C to stop —")
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
        throttled_copyfile(src, dst)   # paced writes for the radio
        flush_fs(); 
        time.sleep(0.05)        
    else:
        shutil.copy(src, dst)          # normal fast copy for everything else


def count_files(dirpath, ext=None):
    total = 0
    for _, _, files in os.walk(dirpath):
        if ext:
            files = [f for f in files if f.endswith(ext)]
        total += len(files)
    return total

# Interactive chooser
def choose_target(targets):
    print("Available targets:")
    for i, t in enumerate(targets, 1):
        mark = '*' if t.get('default') else ' '
        print(f" [{i}] {t['name']} {mark}")
    idx = None
    while idx is None:
        try:
            sel = int(input("Select number: "))
            if 1 <= sel <= len(targets):
                idx = sel - 1
            else:
                print("Out of range")
        except ValueError:
            print("Enter a number")
    return [targets[idx]]

# Copy logic

def copy_files(src_override, fileext, targets):
    global pbar
    git_src = src_override or config['git_src']
    tgt = config['tgt_name']
    print(f"Copy mode: {fileext or 'all'}")

    for i, t in enumerate(targets, 1):
        dest = t['dest']; sim = t.get('simulator')
        print(f"[{i}/{len(targets)}] -> {t['name']} @ {dest}")
        out_dir = os.path.join(dest, tgt)

        # .lua only
        if fileext == '.lua':
            if os.path.isdir(out_dir):
                for r, _, files in os.walk(out_dir):
                    for f in files:
                        if f.endswith(('.lua','.luac')):
                            os.remove(os.path.join(r,f))
            scr = os.path.join(git_src, 'scripts', tgt)
            os.makedirs(out_dir, exist_ok=True)
            for r,_,files in os.walk(scr):
                for f in files:
                    if f.endswith('.lua'):
                        shutil.copy(os.path.join(r,f), out_dir)

        # fast
        # fast
        elif fileext == 'fast':
            scr = os.path.join(git_src, 'scripts', tgt)

            # FAT/exFAT timestamp slack (seconds)
            TS_SLACK = 2.0

            # Collect a stable list first (so bars have fixed totals)
            files_all = []
            for r, _, files in os.walk(scr):
                for f in files:
                    srcf = os.path.join(r, f)
                    rel  = os.path.relpath(srcf, scr)
                    dstf = os.path.join(out_dir, rel)
                    files_all.append((srcf, dstf, rel))

            def needs_copy_with_md5(srcf, dstf):
                """Return True if dstf should be updated from srcf (size/mtime with slack, else MD5)."""
                try:
                    ss = os.stat(srcf)
                except FileNotFoundError:
                    return False  # source vanished
                if not os.path.exists(dstf):
                    return True
                try:
                    ds = os.stat(dstf)
                except FileNotFoundError:
                    return True

                # 1) Different size → copy
                if ss.st_size != ds.st_size:
                    return True
                # 2) Source meaningfully newer → copy
                if (ss.st_mtime - ds.st_mtime) > TS_SLACK:
                    return True
                # 3) Otherwise, verify by MD5
                try:
                    return file_md5(srcf) != file_md5(dstf)
                except Exception:
                    # If hashing fails for any reason, be safe
                    return True

            # ===== Pass 1: Verify (MD5) =====
            to_copy = []
            if files_all:
                bar_verify = tqdm(total=len(files_all), desc="Verifying (MD5)")
                for srcf, dstf, rel in files_all:
                    # Ensure parent exists before we check/copy later
                    os.makedirs(os.path.dirname(dstf), exist_ok=True)
                    if needs_copy_with_md5(srcf, dstf):
                        to_copy.append((srcf, dstf, rel))
                    bar_verify.update(1)
                bar_verify.close()

            # ===== Pass 2: Update only what changed =====
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

            if not copied:
                print("Fast deploy: nothing to update.")
    
        # full
        else:
            srcall = os.path.join(git_src, 'scripts', tgt)
            safe_full_copy(srcall, out_dir)
            flush_fs()
            time.sleep(2)

            print(f"Done: {t['name']}\n")



def patch_logger_init(out_root):
    """
    Set simulatoronly=false in tasks/logger/init.lua, robustly:
    - ignores inline comments (-- ...)
    - preserves spacing and trailing comma
    - matches bare or bracketed keys: simulatoronly or ["simulatoronly"]
    """
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
            code, sep, comment = line.partition('--')   # only touch code part
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


# Launch sims
def launch_sims(targets):
    for t in targets:
        sim = t.get('simulator')
        if sim:
            print(f"Launching {t['name']}: {sim}")
            out = subprocess_conout.subprocess_conout(sim, nrows=9999, encode=True)
            print(out)

# Main
def main():
    global DEPLOY_TO_RADIO
    p = argparse.ArgumentParser(description='Deploy & launch')
    p.add_argument('--config', default=CONFIG_PATH)
    p.add_argument('--src')
    p.add_argument('--fileext')
    p.add_argument('--all', action='store_true')
    p.add_argument('--choose', action='store_true')
    p.add_argument('--launch', action='store_true')
    p.add_argument('--radio', action='store_true')
    p.add_argument('--radio-debug', action='store_true')
    p.add_argument('--minify',    action='store_true')
    p.add_argument('--connect-only', action='store_true')
    args = p.parse_args()

    DEPLOY_TO_RADIO = args.radio 

    DEPLOY_PIDFILE = os.path.join(tempfile.gettempdir(), "rfdeploy-copy.pid")
    try:
        with open(DEPLOY_PIDFILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass
    atexit.register(lambda: os.path.exists(DEPLOY_PIDFILE) and os.remove(DEPLOY_PIDFILE))


    # load override config
    if args.config != CONFIG_PATH:
        with open(args.config) as f:
            config.update(json.load(f))

    # select targets
    if args.radio and args.connect_only:
        # enable serial mode on the radio
        ethos_serial(config['ethossuite_bin'], 'start')

        v = str(config.get('serial_vid', DEFAULT_SERIAL_VID))
        p = str(config.get('serial_pid', DEFAULT_SERIAL_PID))
        b = int(config.get('serial_baud', DEFAULT_SERIAL_BAUD))
        r = int(config.get('serial_retries', DEFAULT_SERIAL_RETRIES))
        d = float(config.get('serial_retry_delay', DEFAULT_SERIAL_DELAY))
        nh = str(config.get('serial_name_hint', "Serial"))

        # now just tail the serial output (until Ctrl+C)
        return tail_serial_debug(vid=v, pid=p, baud=b, retries=r, delay=d, name_hint=nh)
    elif args.radio:
        # Make sure the radio storage is available (serial OFF => mass storage ON)
        print("[ETHOS] Disabling serial debug before copy to protect filesystem…")
        ethos_serial(config['ethossuite_bin'], 'stop')
        # Wait for the radio drive to mount and obtain the SCRIPTS path
        try:
            rd = wait_for_scripts_mount(config['ethossuite_bin'], attempts=10, delay=2)
        except Exception as e:
            print("[ERROR] Failed to obtain Ethos SCRIPTS path after disabling serial.")
            print(f"        Reason: {e}")
            try:
                import winsound
                winsound.MessageBeep()
            except Exception:
                print("", end="", flush=True)
            return 1
        targets = [{'name': 'Radio', 'dest': rd, 'simulator': None}]
    else:
        tlist=config['deploy_targets']
        if args.choose:
            targets=choose_target(tlist)
        elif args.all:
            targets=tlist
        else:
            targets=[t for t in tlist if t.get('default')]

    if not targets:
        print('No targets.')
        sys.exit(1)

    copy_files(args.src, args.fileext, targets)

    # After copying to radio, ensure logger runs on real hardware (not only simulator)
    if args.radio:
        for t in targets:
            out_root = os.path.join(t['dest'], config['tgt_name'])
            patch_logger_init(out_root)

    if args.minify:
        print("→ Minifying Lua files…")
        for t in targets:
            out_root = os.path.join(t['dest'], config['tgt_name'])
            for dirpath, _, files in os.walk(out_root):
                for fn in files:
                    if fn.endswith('.lua'):
                        minify_lua_file(os.path.join(dirpath, fn))
        print("✓ Minification complete.")

    if args.launch and not args.radio:
        launch_sims(targets)


    
    # If deploying to radio without debug, still re-enable serial
    if args.radio and not args.radio_debug:
        ethos_serial(config['ethossuite_bin'], 'start')

    # If deploying to radio WITH debug, (re)enable serial and attach with retries
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
    

if __name__=='__main__':
    rc = main()
    try:
        import sys
        sys.exit(rc if isinstance(rc, int) else 0)
    except SystemExit:
        pass
