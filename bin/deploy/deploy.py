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

DEPLOY_TO_RADIO = False  # flag to control radio-only behavior

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
    Ask Ethos Suite for the SCRIPTS path. Retries after `delay` seconds
    if the tool returns no path or fails. Raises on final failure.
    """
    cmd = [ethossuite_bin, "--get-path", "SCRIPTS"]
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
    os.chmod(path, stat.S_IWRITE)
    func(path)


def flush_fs():
    """Attempt to flush filesystem buffers (best-effort)."""
    try:
        if hasattr(os, "sync"):
            os.sync()
    except Exception as e:
        print(f"[WARN] os.sync failed: {e}")

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
            shutil.rmtree(old_dir, onerror=on_rm_error)
            flush_fs()
            time.sleep(2)

        # Rotate current folder to .old
        try:
            print(f"Renaming existing to {os.path.basename(old_dir)}…")
            os.replace(out_dir, old_dir)  # Atomic on same volume
        except Exception as e:
            print(f"[WARN] Rename failed ({e}). Falling back to direct delete.")
            print("Deleting files…")
            shutil.rmtree(out_dir, onerror=on_rm_error)
        flush_fs()
        time.sleep(2)

        # Delete the rotated .old folder
        if os.path.isdir(old_dir):
            print("Deleting files…")
            shutil.rmtree(old_dir, onerror=on_rm_error)
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
    cmd = [ethossuite_bin, "--serial", action]
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


def wait_for_scripts_mount(ethossuite_bin, attempts=5, delay=2):
    """
    Poll Ethos for the SCRIPTS path until it responds, to confirm the
    radio's storage is mounted and ready for copy.
    """
    last_err = None
    for i in range(attempts):
        try:
            path = get_ethos_scripts_dir(ethossuite_bin, retries=0)
            return path
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
    if DEPLOY_TO_RADIO and os.path.getsize(src) > 5 * 1024:
        flush_fs()
        time.sleep(0.1)
    shutil.copy(src, dst)


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
        elif fileext == 'fast':
            scr = os.path.join(git_src, 'scripts', tgt)
            for r,_,files in os.walk(scr):
                for f in files:
                    srcf = os.path.join(r,f)
                    rel = os.path.relpath(srcf, scr)
                    dstf = os.path.join(out_dir, rel)
                    os.makedirs(os.path.dirname(dstf), exist_ok=True)
                    if not os.path.exists(dstf) or os.path.getmtime(srcf)>os.path.getmtime(dstf):
                        shutil.copy(srcf, dstf)
                        print(f"Copy {f}")

        
        # full
        else:
            srcall = os.path.join(git_src, 'scripts', tgt)
            safe_full_copy(srcall, out_dir)
            flush_fs()
            time.sleep(2)

            print(f"Done: {t['name']}\n")

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
    args = p.parse_args()

    DEPLOY_TO_RADIO = args.radio 

    # load override config
    if args.config != CONFIG_PATH:
        with open(args.config) as f:
            config.update(json.load(f))

    # select targets
    
    if args.radio:
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
