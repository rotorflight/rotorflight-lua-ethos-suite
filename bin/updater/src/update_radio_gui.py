#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Rotorflight Lua Ethos Suite Radio Updater
==========================================
A GUI tool to automatically update Rotorflight Lua Ethos Suite on an Ethos radio
from the latest GitHub master branch.

Features:
- Detects Ethos radio in debug mode
- Switches radio to storage mode
- Downloads latest suite from GitHub
- Updates radio with new files
"""

import os
import sys
import time
import shutil
import tempfile
import zipfile
import threading
import subprocess
import re
import ssl
import traceback
import math
import json
import hashlib
import webbrowser
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
import atexit

# GUI imports
try:
    import tkinter as tk
    from tkinter import ttk, scrolledtext, messagebox, filedialog
except ImportError:
    print("Error: tkinter is required but not found.")
    sys.exit(1)

# HID imports for radio communication
HID_IMPORT_ERROR = None
HID_MODULE_PATH = None
try:
    import hid as _hid
    if hasattr(_hid, "device"):
        hid = _hid
        HID_MODULE_PATH = getattr(_hid, "__file__", None)
    else:
        raise ImportError("hid module missing 'device' attribute")
except Exception as e:
    HID_IMPORT_ERROR = str(e)
    try:
        import hidapi as _hid
        if hasattr(_hid, "device"):
            hid = _hid
            HID_MODULE_PATH = getattr(_hid, "__file__", None)
        else:
            hid = None
    except Exception as e2:
        HID_IMPORT_ERROR = f"{HID_IMPORT_ERROR}; hidapi fallback failed: {e2}"
        hid = None

# Windows-specific imports for drive detection
if sys.platform == 'win32':
    try:
        import win32api
        import win32file
    except ImportError:
        print("Warning: pywin32 not found. Install with: pip install pywin32")
        win32api = None
        win32file = None
else:
    win32api = None
    win32file = None


# Constants
GITHUB_REPO_URL = "https://github.com/rotorflight/rotorflight-lua-ethos-suite"
GITHUB_API_URL = "https://api.github.com/repos/rotorflight/rotorflight-lua-ethos-suite"
ETHOS_VID = 0x0483
ETHOS_PID = 0x5750
TARGET_NAME = "rfsuite"
DEFAULT_LOCALE = "en"
AVAILABLE_LOCALES = ["en", "de", "es", "fr", "it", "nl", "pt-br", "no", "cs", "pl", "he", "zh-cn"]
DOWNLOAD_TIMEOUT = 120
DOWNLOAD_RETRIES = 3
DOWNLOAD_RETRY_DELAY = 2
COPY_SETTLE_SECONDS = 0.03
TS_SLACK_SECONDS = 2.0
CACHE_DIRNAME = "cache"
LOGO_URL = "https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/bin/updater/src/logo.png"
UPDATER_VERSION = "1.0.3"
UPDATER_RELEASE_JSON_URL = "https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/bin/updater/src/release.json"
UPDATER_INFO_URL = "https://github.com/rotorflight/rotorflight-lua-ethos-suite/tree/master/bin/updater/"
def _get_app_dir():
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parent


APP_DIR = _get_app_dir()
def _get_work_dir():
    # Keep runtime files out of the current working directory on macOS/Linux.
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "rfsuite-updater"
    if sys.platform.startswith("linux"):
        return Path.home() / ".local" / "share" / "rfsuite-updater"
    return APP_DIR / "rfsuite_updater_work"

WORK_DIR = _get_work_dir()
try:
    WORK_DIR.mkdir(parents=True, exist_ok=True)
except Exception:
    WORK_DIR = Path(tempfile.gettempdir()) / "rfsuite_updater_work"
    WORK_DIR.mkdir(parents=True, exist_ok=True)

UPDATER_LOCK_FILE = str(WORK_DIR / "rfsuite_updater.lock")


def _ensure_work_dir():
    try:
        WORK_DIR.mkdir(parents=True, exist_ok=True)
    except Exception:
        pass


def _cleanup_work_dir():
    try:
        if WORK_DIR.is_dir():
            for item in WORK_DIR.iterdir():
                if item.name == CACHE_DIRNAME:
                    continue
                if item.name == os.path.basename(UPDATER_LOCK_FILE):
                    continue
                try:
                    if item.is_dir():
                        shutil.rmtree(item)
                    else:
                        item.unlink()
                except Exception:
                    pass
            try:
                WORK_DIR.rmdir()
            except Exception:
                pass
    except Exception:
        pass


def _clear_cache_dir():
    try:
        cache_dir = WORK_DIR / CACHE_DIRNAME
        if cache_dir.is_dir():
            shutil.rmtree(cache_dir)
        return True
    except Exception:
        return False

# Version types
VERSION_RELEASE = "release"
VERSION_SNAPSHOT = "snapshot"
VERSION_MASTER = "master"

# i18n tag resolution (embedded to support onefile builds)
TAG_RE = re.compile(
    r'@i18n\(\s*([^)@,]+?)\s*(?:,\s*(upper|lower))?\s*\)'
    r'((?::[a-z_]+(?:\([^@]*?\))?)*)@',
    flags=re.IGNORECASE
)

def _i18n_coerce_atom(s):
    try:
        return int(s)
    except ValueError:
        try:
            return float(s)
        except ValueError:
            if s.lower() in ("true", "false"):
                return s.lower() == "true"
            return s

def _i18n_parse_chain(chain):
    if not chain:
        return []
    out = []
    for seg in filter(None, chain.split(":")):
        m = re.match(r'([a-z_][a-z0-9_]*)\s*(?:\((.*)\))?$', seg, flags=re.IGNORECASE)
        if not m:
            continue
        name, argstr = m.group(1).lower(), (m.group(2) or "").strip()
        args = []
        if argstr:
            parts = []
            current = ""
            depth = 0
            for ch in argstr:
                if ch == "(":
                    depth += 1
                    current += ch
                elif ch == ")":
                    depth = max(0, depth - 1)
                    current += ch
                elif ch == "," and depth == 0:
                    parts.append(current.strip())
                    current = ""
                else:
                    current += ch
            if current.strip():
                parts.append(current.strip())
            for p in parts:
                parsed = p.strip()
                if parsed.startswith(("'", '"')) and parsed.endswith(("'", '"')) and len(parsed) >= 2:
                    parsed = parsed[1:-1]
                if parsed == "":
                    args.append("")
                else:
                    args.append(_i18n_coerce_atom(parsed))
        out.append((name, args, {}))
    return out

def _i18n_upperfirst(s):
    return s[:1].upper() + s[1:].lower() if s else s

def _i18n_truncate(s, n, ellipsis=None):
    if n < 0:
        return s
    if len(s) <= n:
        return s
    if ellipsis:
        if n <= len(ellipsis):
            return ellipsis[:n]
        return s[: n - len(ellipsis)] + ellipsis
    return s[:n]

def _i18n_collapse_ws(s):
    return re.sub(r'\s+', ' ', s).strip()

def _i18n_slice(s, start, end=None):
    return s[start:end]

def _i18n_ensure_char(c):
    return c[0] if isinstance(c, str) and c else " "

I18N_TRANSFORMS = {
    "upper": lambda s: s.upper(),
    "lower": lambda s: s.lower(),
    "upperfirst": _i18n_upperfirst,
    "capitalize": lambda s: s[:1].upper() + s[1:],
    "title": lambda s: s.title(),
    "swapcase": lambda s: s.swapcase(),
    "trim": lambda s: s.strip(),
    "ltrim": lambda s: s.lstrip(),
    "rtrim": lambda s: s.rstrip(),
    "collapse_ws": _i18n_collapse_ws,
    "truncate": lambda s, n, ellipsis=None: _i18n_truncate(s, int(n), ellipsis),
    "slice": _i18n_slice,
    "padleft": lambda s, width, char=" ": s.rjust(int(width), _i18n_ensure_char(char)),
    "padright": lambda s, width, char=" ": s.ljust(int(width), _i18n_ensure_char(char)),
    "center": lambda s, width, char=" ": s.center(int(width), _i18n_ensure_char(char)),
    "replace": lambda s, old, new, count=None: s.replace(str(old), str(new), int(count) if count is not None else -1),
    "remove": lambda s, pattern: re.sub(str(pattern), "", s),
    "keep": lambda s, pattern: " ".join(re.findall(str(pattern), s)),
    "strip_prefix": lambda s, p: s[len(p):] if s.startswith(str(p)) else s,
    "strip_suffix": lambda s, p: s[:-len(p)] if len(p) and s.endswith(str(p)) else s,
    "prefix": lambda s, p: str(p) + s,
    "suffix": lambda s, p: s + str(p),
    "escape_html": lambda s: (
        s.replace("&", "&amp;")
         .replace("<", "&lt;")
         .replace(">", "&gt;")
         .replace('"', "&quot;")
         .replace("'", "&#x27;")
    ),
    "escape_json": lambda s: s.replace("\\", "\\\\").replace('"', r'\"'),
}

def _i18n_apply_transform_pipeline(s, basic_mod, chain, stats):
    if basic_mod:
        fn = I18N_TRANSFORMS.get(basic_mod.lower())
        if fn:
            s = fn(s)
    for name, args, _ in _i18n_parse_chain(chain):
        fn = I18N_TRANSFORMS.get(name)
        if not fn:
            stats.setdefault("unknown_transform", {}).setdefault(name, 0)
            stats["unknown_transform"][name] += 1
            continue
        try:
            s = fn(s, *args)
        except Exception as e:
            stats.setdefault("transform_errors", []).append(f"{name}({args}) -> {e}")
    return s

def _i18n_load_translations(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)

def _i18n_resolve_key(tree, dotted):
    node = tree
    for part in dotted.split("."):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    if isinstance(node, dict):
        reverse_flag = node.get("reverse_text") if isinstance(node.get("reverse_text"), bool) else None
        if "translation" in node and isinstance(node["translation"], (str, int, float)):
            return str(node["translation"]), reverse_flag
        if "english" in node and isinstance(node["english"], (str, int, float)):
            return str(node["english"]), reverse_flag
        return None
    if node is None:
        return None
    return str(node), None

def _i18n_sanitize_for_insertion(s):
    s = s.replace("\r\n", "\n").replace("\r", "\n")
    s = s.replace("\n", r"\n")
    s = s.replace('"', r'\"')
    return s

def _i18n_reverse_text_for_hebrew_display(s):
    normalized = s.replace("\r\n", "\n").replace("\r", "\n")
    return "\n".join(line[::-1] for line in normalized.split("\n"))

def _i18n_contains_hebrew_chars(s):
    return re.search(r"[\u0590-\u05FF]", s) is not None

def _i18n_should_reverse_text(text, reverse_flag):
    if reverse_flag is True:
        return True
    if reverse_flag is False:
        return False
    return _i18n_contains_hebrew_chars(text)

def _i18n_replace_tags_in_text(text, translations, stats):
    def _sub(m):
        key = m.group(1).strip()
        basic_mod = m.group(2)
        chain = m.group(3) or ""
        resolved = _i18n_resolve_key(translations, key)
        if resolved is None:
            stats.setdefault("unresolved", {}).setdefault(key, 0)
            stats["unresolved"][key] += 1
            return m.group(0)
        resolved_text, reverse_flag = resolved
        resolved_text = _i18n_apply_transform_pipeline(str(resolved_text), basic_mod, chain, stats)
        if _i18n_should_reverse_text(resolved_text, reverse_flag):
            resolved_text = _i18n_reverse_text_for_hebrew_display(resolved_text)
        resolved_text = _i18n_sanitize_for_insertion(resolved_text)
        return resolved_text
    new_text, n = TAG_RE.subn(_sub, text)
    return new_text, n

def _i18n_process_file(path, translations, dry_run=False):
    before = path.read_text(encoding="utf-8")
    stats = {}
    new_text, n = _i18n_replace_tags_in_text(before, translations, stats)
    if n == 0:
        return 0, stats.get("unresolved", {})
    if dry_run:
        return n, stats.get("unresolved", {})
    try:
        path.write_text(new_text, encoding="utf-8")
    except Exception:
        return 0, stats.get("unresolved", {})
    return n, stats.get("unresolved", {})

def _i18n_iter_source_files(root, exts=(".lua", ".ts", ".tsx", ".js", ".jsx", ".json", ".md", ".txt")):
    for p in Path(root).rglob("*"):
        if p.is_file() and p.suffix.lower() in exts:
            yield p

def compile_i18n_tags(json_path, root_dir, log_cb=None):
    translations = _i18n_load_translations(json_path)
    total_files_changed = 0
    total_replacements = 0
    unresolved_agg = {}
    def _emit(msg):
        if log_cb:
            log_cb(msg)
        try:
            print(msg)
        except Exception:
            pass
    
    root_path = Path(root_dir)
    for f in _i18n_iter_source_files(root_dir):
        replaced, unresolved = _i18n_process_file(f, translations, dry_run=False)
        if replaced:
            total_files_changed += 1
            total_replacements += replaced
            try:
                rel = f.relative_to(root_path)
                _emit(f"[i18n] {rel} ({replaced} repl)")
            except Exception:
                _emit(f"[i18n] {f} ({replaced} repl)")
        for k, c in unresolved.items():
            unresolved_agg[k] = unresolved_agg.get(k, 0) + c

    _emit(f"[i18n] DONE - files changed: {total_files_changed}, total replacements: {total_replacements}")
    if unresolved_agg:
        _emit("[i18n] Unresolved keys (top 20):")
        for k, c in sorted(unresolved_agg.items(), key=lambda kv: (-kv[1], kv[0]))[:20]:
            _emit(f"  {k}: {c}")
    return total_files_changed, total_replacements, unresolved_agg

# USB Mode Request Commands
ETHOS_SUITE_USB_MODE_REQUEST = 0x81
USB_MODE_STORAGE = 0x69  # Stop debug mode = enable storage mode
USB_MODE_DEBUG = 0x68    # Start debug mode


class RadioInterface:
    """Interface to communicate with Ethos radio via USB HID."""
    
    def __init__(self, log_cb=None):
        self.device = None
        self.drives = {}
        self.log_cb = log_cb

    def _log(self, message):
        if self.log_cb:
            self.log_cb(message)
    
    def connect(self):
        """Connect to the Ethos radio."""
        if hid is None:
            details = f"hid import failed: {HID_IMPORT_ERROR}" if HID_IMPORT_ERROR else "hid import failed"
            raise RuntimeError(f"hidapi module not available or invalid. {details}")
        
        try:
            if HID_MODULE_PATH:
                self._log(f"HID module: {HID_MODULE_PATH}")
            # Try to open the HID device
            self.device = hid.device()
            self.device.open(ETHOS_VID, ETHOS_PID)
            return True
        except Exception as e:
            raise RuntimeError(f"Failed to connect to radio: {e}")
    
    def disconnect(self):
        """Disconnect from the radio."""
        if self.device:
            try:
                self.device.close()
            except Exception:
                pass
            self.device = None
    
    def switch_to_storage_mode(self):
        """Switch radio from debug mode to storage mode."""
        if not self.device:
            raise RuntimeError("Not connected to radio")
        
        try:
            # Send USB mode request to enable storage mode
            self.device.write(bytes([0x00, ETHOS_SUITE_USB_MODE_REQUEST, USB_MODE_STORAGE]))
            time.sleep(2)  # Wait for mode switch
            return True
        except Exception as e:
            raise RuntimeError(f"Failed to switch to storage mode: {e}")
    
    def _iter_mount_roots(self):
        """Yield potential mount roots on Unix-like systems."""
        for base in ["/Volumes", "/media", "/mnt", "/run/media"]:
            if not os.path.isdir(base):
                continue
            try:
                for entry in os.scandir(base):
                    if not entry.is_dir():
                        continue
                    # Common layout on Linux: /run/media/<user>/<label>
                    if base in ("/run/media", "/media"):
                        try:
                            for sub in os.scandir(entry.path):
                                if sub.is_dir():
                                    yield sub.path
                        except Exception:
                            continue
                    # Direct mount under base (macOS /Volumes, some /mnt)
                    yield entry.path
            except Exception:
                continue

    def _iter_lsblk_mounts(self):
        """Yield mount points from lsblk for removable/SD devices (Linux)."""
        if sys.platform == "darwin":
            return
        try:
            # Use lsblk key=value output for robust parsing.
            result = subprocess.run(
                ["lsblk", "-o", "NAME,TRAN,RM,SIZE,MOUNTPOINT", "-P"],
                capture_output=True,
                text=True,
                check=False,
            )
            if result.returncode != 0 or not result.stdout:
                return
            for line in result.stdout.splitlines():
                # Parse KEY="VALUE" pairs
                parts = {}
                for m in re.finditer(r'(\\w+)=\"(.*?)\"', line):
                    parts[m.group(1)] = m.group(2)
                name = parts.get("NAME", "")
                tran = parts.get("TRAN", "")
                mountpoint = parts.get("MOUNTPOINT", "")
                if not mountpoint:
                    continue
                # Prefer USB devices or mmc (SD/eMMC) devices
                if tran == "usb" or name.startswith("mmc"):
                    yield mountpoint
        except Exception:
            return

    def scan_for_drives(self):
        """Scan for mounted radio drives."""
        self.drives = {}
        
        if sys.platform == 'win32':
            if win32api is None or win32file is None:
                raise RuntimeError("pywin32 module not available. Install with: pip install pywin32")
            
            # Scan Windows drives
            for drive in win32api.GetLogicalDriveStrings().split('\x00')[:-1]:
                try:
                    dtype = win32file.GetDriveType(drive)
                    if dtype != win32file.DRIVE_REMOVABLE:
                        continue
                    
                    # Check for Ethos markers
                    for key in ('flash', 'sdcard', 'radio'):
                        marker = os.path.join(drive, key + ".cpuid")
                        if os.path.exists(marker):
                            self.drives[key] = drive.replace("\\", "")
                except Exception:
                    continue
        else:
            # Unix-like systems
            for root in self._iter_mount_roots():
                for key in ('flash', 'sdcard', 'radio'):
                    marker = os.path.join(root, key + ".cpuid")
                    if os.path.exists(marker):
                        self.drives[key] = root
        
        return self.drives
    
    def get_scripts_dir(self):
        """Get the scripts directory on the mounted radio."""
        self.scan_for_drives()
        
        # Prefer sdcard/radio over flash
        for key in ("sdcard", "radio", "flash"):
            root = self.drives.get(key)
            if root:
                scripts = os.path.join(root, "scripts")
                if os.path.isdir(scripts):
                    return os.path.normpath(scripts)
        
        return None

    def find_scripts_dir_on_drives(self, removable_only=True):
        """Fallback: scan drives for scripts folder."""
        if sys.platform == 'win32':
            if win32api is None or win32file is None:
                return None
            for drive in win32api.GetLogicalDriveStrings().split('\x00')[:-1]:
                try:
                    dtype = win32file.GetDriveType(drive)
                    if removable_only and dtype != win32file.DRIVE_REMOVABLE:
                        continue
                    for folder in ("scripts", "script"):
                        scripts = os.path.join(drive, folder)
                        if os.path.isdir(scripts):
                            return os.path.normpath(scripts)
                except Exception:
                    continue
            return None
        else:
            for root in self._iter_mount_roots():
                for folder in ("scripts", "script"):
                    scripts = os.path.join(root, folder)
                    if os.path.isdir(scripts):
                        return os.path.normpath(scripts)
            # Linux fallback: inspect lsblk for removable mounts
            for root in self._iter_lsblk_mounts():
                for folder in ("scripts", "script"):
                    scripts = os.path.join(root, folder)
                    if os.path.isdir(scripts):
                        return os.path.normpath(scripts)
            return None


class UpdaterGUI:
    """Main GUI application for updating the radio."""
    
    def __init__(self, root):
        self.root = root
        self.root.title("Rotorflight Lua Ethos Suite Updater")
        self.root.geometry("800x800")
        self.root.resizable(False, False)
        
        self.update_thread = None
        self.is_updating = False
        self.selected_version = tk.StringVar(value=VERSION_RELEASE)
        self.selected_locale = tk.StringVar(value=DEFAULT_LOCALE)
        self.chkdsk_attempted = False
        
        self.setup_ui()
        self.radio = RadioInterface(self.log)
    
    def setup_ui(self):
        """Setup the user interface."""
        # Title (dark header)
        header_bg = "#1f1f1f"
        header_fg = "#f2f2f2"
        title_frame = tk.Frame(self.root, bg=header_bg)
        title_frame.pack(fill=tk.X)
        title_frame.pack_propagate(False)
        title_frame.configure(height=90)

        # Layout: text on left, logo on right (if available)
        text_frame = tk.Frame(title_frame, bg=header_bg)
        text_frame.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=10, pady=10)

        title_label = tk.Label(
            text_frame,
            text="Rotorflight Lua Ethos Suite Updater",
            font=("Arial", 16, "bold"),
            bg=header_bg,
            fg=header_fg
        )
        title_label.pack(anchor=tk.W)

        subtitle_text = "Open-source Helicopter flight controller"

        # Right side: logo with tagline overlay (logo loads async)
        logo_frame = tk.Frame(title_frame, bg=header_bg, width=340, height=80)
        logo_frame.pack(side=tk.RIGHT, padx=(10, 10), pady=10)
        logo_frame.pack_propagate(False)
        self.logo_label = None
        self.logo_image = None
        subtitle_right = tk.Label(
            logo_frame,
            text=subtitle_text,
            font=("Arial", 9),
            bg=header_bg,
            fg=header_fg
        )

        # Left strapline under title
        subtitle_left = tk.Label(
            text_frame,
            text="Update your Ethos radio with the latest suite from GitHub",
            font=("Arial", 10),
            bg=header_bg,
            fg=header_fg
        )
        subtitle_left.pack(anchor=tk.W, pady=(2, 0))

        def set_logo_image(path):
            try:
                logo_img = tk.PhotoImage(file=str(path))
                target_h = logo_frame.winfo_reqheight() or 80
                target_w = logo_frame.winfo_reqwidth() or 340
                scale_h = math.ceil(logo_img.height() / target_h)
                scale_w = math.ceil(logo_img.width() / target_w)
                scale = max(1, scale_h, scale_w)
                if scale > 1:
                    logo_img = logo_img.subsample(scale, scale)
                self.logo_image = logo_img
                if not self.logo_label:
                    self.logo_label = tk.Label(logo_frame, image=self.logo_image, bg=header_bg)
                else:
                    self.logo_label.configure(image=self.logo_image)

                # Place logo and overlay tagline within the logo frame
                self.logo_label.place(relx=1.0, x=0, y=-5, anchor=tk.NE)
                subtitle_right.place(relx=1.0, x=-6, y=52, anchor=tk.NE)
                subtitle_right.lift()
            except Exception:
                pass

        # Async fetch logo to avoid blocking UI
        def fetch_logo():
            try:
                _ensure_work_dir()
                req = Request(LOGO_URL, headers={'User-Agent': 'Mozilla/5.0'})
                with self.urlopen_insecure(req, timeout=10) as response:
                    logo_bytes = response.read()
                tmp_logo = WORK_DIR / "rfsuite_logo.png"
                with open(tmp_logo, "wb") as f:
                    f.write(logo_bytes)
                self.root.after(0, lambda: set_logo_image(tmp_logo))
            except Exception:
                pass

        threading.Thread(target=fetch_logo, daemon=True).start()
        
        # Version selection frame
        version_frame = ttk.LabelFrame(self.root, text="Version Selection", padding="10")
        version_frame.pack(fill=tk.X, padx=10, pady=5)
        
        version_label = ttk.Label(
            version_frame,
            text="Select version to install:",
            font=("Arial", 9)
        )
        version_label.pack(side=tk.LEFT, padx=5)
        
        # Radio buttons for version selection
        ttk.Radiobutton(
            version_frame,
            text="Release (Stable)",
            variable=self.selected_version,
            value=VERSION_RELEASE
        ).pack(side=tk.LEFT, padx=5)
        
        ttk.Radiobutton(
            version_frame,
            text="Snapshot (Pre-release)",
            variable=self.selected_version,
            value=VERSION_SNAPSHOT
        ).pack(side=tk.LEFT, padx=5)
        
        ttk.Radiobutton(
            version_frame,
            text="Master (Latest)",
            variable=self.selected_version,
            value=VERSION_MASTER
        ).pack(side=tk.LEFT, padx=5)
        # Language selection (within version frame)
        locale_label = ttk.Label(
            version_frame,
            text="Language:",
            font=("Arial", 9)
        )
        locale_label.pack(side=tk.LEFT, padx=10)

        locale_combo = ttk.Combobox(
            version_frame,
            textvariable=self.selected_locale,
            values=AVAILABLE_LOCALES,
            state="readonly",
            width=8
        )
        locale_combo.pack(side=tk.LEFT, padx=5)

        # Status frame
        status_frame = ttk.LabelFrame(self.root, text="Status", padding="10")
        status_frame.pack(fill=tk.X, padx=10, pady=5)
        
        self.status_label = ttk.Label(
            status_frame,
            text="Ready to update",
            font=("Arial", 10)
        )
        self.status_label.pack()
        
        # Progress label (shows file count during operations)
        self.progress_label = ttk.Label(
            status_frame,
            text="",
            font=("Arial", 8)
        )
        self.progress_label.pack()
        
        # Segmented progress bar with labels
        self.step_names = [
            "Find",
            "Connect",
            "Download",
            "Extract",
            "Translate",
            "Copy",
            "Audio",
            "Cleanup",
        ]
        self.segment_bar = tk.Canvas(
            status_frame,
            height=36,
            highlightthickness=1,
            highlightbackground="#bdbdbd",
            bg="#f2f2f2"
        )
        self.segment_bar.pack(fill=tk.X, padx=8, pady=5)
        self.segment_items = []
        self.segment_labels = []
        self.segment_states = [False for _ in self.step_names]
        self.segment_active_index = None
        self.segment_pulse_on = False
        self.segment_pulse_after_id = None
        self._draw_segment_bar()
        self.root.bind("<Configure>", lambda _e: self._draw_segment_bar())
        
        # Log frame
        log_frame = ttk.LabelFrame(self.root, text="Log", padding="10")
        log_frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=5)
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            wrap=tk.WORD,
            height=15,
            font=("Consolas", 9)
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # Buttons frame
        button_frame = ttk.Frame(self.root, padding="10")
        button_frame.pack(fill=tk.X)
        
        self.update_button = ttk.Button(
            button_frame,
            text="Start Update",
            command=self.start_update,
            style="Accent.TButton"
        )
        self.update_button.pack(side=tk.LEFT, padx=5)
        
        self.cancel_button = ttk.Button(
            button_frame,
            text="Cancel",
            command=self.cancel_update,
            state=tk.DISABLED
        )
        self.cancel_button.pack(side=tk.LEFT, padx=5)

        self.save_log_button = ttk.Button(
            button_frame,
            text="Save Log",
            command=self.save_log
        )
        self.save_log_button.pack(side=tk.LEFT, padx=5)

        self.clear_cache_button = ttk.Button(
            button_frame,
            text="Delete Cache",
            command=self.delete_cache
        )
        self.clear_cache_button.pack(side=tk.LEFT, padx=5)
        
        ttk.Button(
            button_frame,
            text="Exit",
            command=self.root.quit
        ).pack(side=tk.RIGHT, padx=5)
        
        # Info frame
        info_frame = ttk.LabelFrame(self.root, text="Instructions", padding="10")
        info_frame.pack(fill=tk.X, padx=10, pady=5)
        
        info_text = (
            "1. Select the version you want to install (Release recommended)\n"
            "2. Connect your Ethos radio via USB\n"
            "3. Click 'Start Update' to begin\n"
            "4. Wait for the update to complete"
        )
        
        ttk.Label(
            info_frame,
            text=info_text,
            font=("Arial", 8),
            justify=tk.LEFT
        ).pack(anchor=tk.W)

        # Updater update notification (always visible)
        self.update_notice = ttk.Frame(self.root, padding="8")
        self.update_notice.pack(fill=tk.X, padx=10, pady=(0, 5))
        
        self.update_notice_label = ttk.Label(
            self.update_notice,
            text=f"Checking for updates... (Current: {UPDATER_VERSION})",
            font=("Arial", 9)
        )
        self.update_notice_label.pack(side=tk.LEFT)
        
        self.update_notice_button = ttk.Button(
            self.update_notice,
            text="Open Download Page",
            command=lambda: webbrowser.open(UPDATER_INFO_URL)
        )
        self.update_notice_button.pack(side=tk.RIGHT)

        # Async check for updater updates
        threading.Thread(target=self.check_updater_update, daemon=True).start()
    
    def log(self, message):
        """Add a message to the log."""
        timestamp = time.strftime("%H:%M:%S")
        self.log_text.insert(tk.END, f"[{timestamp}] {message}\n")
        self.log_text.see(tk.END)
        self.root.update_idletasks()

    def urlopen_insecure(self, req, timeout=10):
        """Open URL without SSL verification (to avoid SSL issues on some systems)."""
        context = ssl._create_unverified_context()
        return urlopen(req, timeout=timeout, context=context)

    def _download_cache_dir(self):
        p = WORK_DIR / CACHE_DIRNAME / "downloads"
        p.mkdir(parents=True, exist_ok=True)
        return p

    def _download_cache_paths(self, url):
        key = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
        base = self._download_cache_dir() / key
        return str(base.with_suffix(".zip")), str(base.with_suffix(".json"))

    def _read_json_file(self, path):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}

    def _write_json_file(self, path, payload):
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump(payload, f)
        except Exception:
            pass

    def _download_zip_with_cache(self, download_url):
        """
        Download release/snapshot zip with local cache revalidation.
        - Uses If-None-Match / If-Modified-Since when cache metadata exists.
        - On HTTP 304, reuses cached file.
        - On download failure, falls back to cached file if present.
        """
        cache_zip, cache_meta = self._download_cache_paths(download_url)
        meta = self._read_json_file(cache_meta)
        has_cache = os.path.isfile(cache_zip)

        if has_cache:
            self.log(f"  Cache candidate found: {os.path.basename(cache_zip)}")

        attempt = 0
        while True:
            attempt += 1
            headers = {'User-Agent': 'Mozilla/5.0'}
            if has_cache:
                etag = meta.get("etag")
                last_mod = meta.get("last_modified")
                if etag:
                    headers["If-None-Match"] = etag
                if last_mod:
                    headers["If-Modified-Since"] = last_mod

            req = Request(download_url, headers=headers)
            try:
                self.log(f"  Download attempt {attempt}/{DOWNLOAD_RETRIES} (timeout {DOWNLOAD_TIMEOUT}s)")
                with self.urlopen_insecure(req, timeout=DOWNLOAD_TIMEOUT) as response:
                    total_size = int(response.headers.get('content-length', 0))
                    size_known = total_size > 0
                    downloaded = 0

                    if size_known:
                        self.update_progress(0, "Downloading...")
                    else:
                        total_size = 50 * 1024 * 1024
                        self.update_progress(0, "Downloading (size unknown)...")
                        self.log("  Download size unknown (no content-length); estimating 50MB")

                    last_log_percent = -1
                    tmp_zip = cache_zip + ".part"
                    with open(tmp_zip, 'wb') as f:
                        while True:
                            if not self.is_updating:
                                return None
                            chunk = response.read(8192)
                            if not chunk:
                                break
                            f.write(chunk)
                            downloaded += len(chunk)
                            percent = (downloaded / total_size) * 100 if total_size > 0 else 0
                            if int(percent) != last_log_percent:
                                last_log_percent = int(percent)
                                if size_known:
                                    self.log(f"  Downloaded: {downloaded}/{total_size} bytes ({percent:.1f}%)")
                                else:
                                    self.log(f"  Downloaded: {downloaded}/{total_size} bytes ({percent:.1f}%) (estimated)")
                            self.update_progress(downloaded, f"Downloading... {percent:.1f}%")

                    os.replace(tmp_zip, cache_zip)
                    meta = {
                        "url": download_url,
                        "etag": response.headers.get("ETag"),
                        "last_modified": response.headers.get("Last-Modified"),
                        "cached_at": int(time.time()),
                    }
                    self._write_json_file(cache_meta, meta)
                    self.log(f"✓ Downloaded {downloaded} bytes")
                    return cache_zip

            except HTTPError as e:
                if e.code == 304 and has_cache:
                    self.log("  Remote unchanged (HTTP 304). Using cached download.")
                    return cache_zip
                if attempt >= DOWNLOAD_RETRIES:
                    if has_cache:
                        self.log(f"⚠ Download failed ({e}); using cached download.")
                        return cache_zip
                    raise
                self.log(f"  Download failed: {e}. Retrying in {DOWNLOAD_RETRY_DELAY}s...")
                time.sleep(DOWNLOAD_RETRY_DELAY)
            except URLError as e:
                if attempt >= DOWNLOAD_RETRIES:
                    if has_cache:
                        self.log(f"⚠ Download failed ({e}); using cached download.")
                        return cache_zip
                    raise
                self.log(f"  Download failed: {e}. Retrying in {DOWNLOAD_RETRY_DELAY}s...")
                time.sleep(DOWNLOAD_RETRY_DELAY)

    def _parse_version_tuple(self, version):
        try:
            parts = version.strip().split(".")
            return tuple(int(p) for p in parts)
        except Exception:
            return None

    def _is_newer_version(self, current, remote):
        cur = self._parse_version_tuple(current)
        rem = self._parse_version_tuple(remote)
        if cur is None or rem is None:
            return current != remote
        return rem > cur

    def check_updater_update(self):
        """Check if a newer updater version is available."""
        try:
            req = Request(UPDATER_RELEASE_JSON_URL, headers={'User-Agent': 'Mozilla/5.0'})
            with self.urlopen_insecure(req, timeout=10) as response:
                data = json.loads(response.read().decode())
            remote_version = data.get("version", "").strip()
            remote_url = data.get("url") or UPDATER_INFO_URL
            if remote_version:
                if self._is_newer_version(UPDATER_VERSION, remote_version):
                    msg = f"New version available. Current: {UPDATER_VERSION} | Latest: {remote_version}"
                else:
                    msg = f"Updater is up to date. Current: {UPDATER_VERSION} | Latest: {remote_version}"
                self.root.after(0, lambda: self.show_update_notice(msg, remote_url))
            else:
                msg = f"Updater version check failed. Current: {UPDATER_VERSION} | Latest: unknown"
                self.root.after(0, lambda: self.show_update_notice(msg, UPDATER_INFO_URL))
        except Exception:
            msg = f"Updater version check failed. Current: {UPDATER_VERSION} | Latest: unknown"
            self.root.after(0, lambda: self.show_update_notice(msg, UPDATER_INFO_URL))

    def show_update_notice(self, message, url):
        self.update_notice_label.config(text=message)
        self.update_notice_button.config(command=lambda: webbrowser.open(url))
        self.update_notice.pack(fill=tk.X, padx=10, pady=(0, 5))

    def save_log(self):
        """Save the current log to a user-selected file."""
        try:
            log_text = self.log_text.get("1.0", tk.END)
        except Exception:
            log_text = ""
        if not log_text.strip():
            messagebox.showinfo("Save Log", "There is no log content to save yet.")
            return
        filename = filedialog.asksaveasfilename(
            title="Save Updater Log",
            defaultextension=".txt",
            initialfile="rfsuite_updater_log.txt",
            filetypes=[("Text Files", "*.txt"), ("All Files", "*.*")]
        )
        if not filename:
            return
        try:
            with open(filename, "w", encoding="utf-8") as f:
                f.write(log_text)
            messagebox.showinfo("Save Log", f"Log saved to:\n{filename}")
        except Exception as e:
            messagebox.showerror("Save Log", f"Failed to save log:\n{e}")

    def delete_cache(self):
        """Delete updater cache (download and sparse git caches) after confirmation."""
        if self.is_updating:
            messagebox.showinfo("Delete Cache", "Cannot delete cache while an update is running.")
            return
        confirmed = messagebox.askyesno(
            "Delete Cache",
            "Delete cached downloads and cached master sparse checkout?\n\n"
            "This will force fresh network fetches on the next update."
        )
        if not confirmed:
            return
        ok = _clear_cache_dir()
        if ok:
            self.log("Cache deleted by user.")
            messagebox.showinfo("Delete Cache", "Updater cache deleted.")
        else:
            self.log("⚠ Failed to delete cache.")
            messagebox.showerror("Delete Cache", "Failed to delete cache.")
    
    def set_status(self, message):
        """Update the status label."""
        self.status_label.config(text=message)
        self.root.update_idletasks()
    
    def set_progress_mode(self, mode='indeterminate', maximum=100):
        """No-op (progress bar removed)."""
        self.root.update_idletasks()
    
    def update_progress(self, value, text=""):
        """Update progress label."""
        self.progress_label.config(text=text)
        self.root.update_idletasks()

    def _draw_segment_bar(self):
        if not hasattr(self, "segment_bar"):
            return
        self.segment_bar.delete("all")
        self.segment_items = []
        self.segment_labels = []
        width = max(1, self.segment_bar.winfo_width())
        height = int(self.segment_bar["height"])
        padding = 6
        gap = 4
        label_h = 14
        bar_h = height - padding * 2 - label_h
        bar_y1 = padding
        bar_y2 = padding + bar_h
        total_segments = len(self.step_names)
        seg_w = max(1, (width - padding * 2 - gap * (total_segments - 1)) // total_segments)
        x = padding
        for i, name in enumerate(self.step_names):
            if self.segment_states[i]:
                fill = "#1db954"
            elif self.segment_active_index == i:
                fill = "#f4a259" if self.segment_pulse_on else "#d9d9d9"
            else:
                fill = "#d9d9d9"
            rect = self.segment_bar.create_rectangle(
                x,
                bar_y1,
                x + seg_w,
                bar_y2,
                fill=fill,
                outline="#bdbdbd"
            )
            label = self.segment_bar.create_text(
                x + seg_w / 2,
                bar_y2 + label_h / 2,
                text=name,
                fill="#333333",
                font=("Arial", 8)
            )
            self.segment_items.append(rect)
            self.segment_labels.append(label)
            x += seg_w + gap

    def reset_steps(self):
        self.segment_states = [False for _ in self.step_names]
        self._stop_segment_pulse()
        self._draw_segment_bar()

    def mark_step_done(self, step_name):
        if step_name not in self.step_names:
            return
        idx = self.step_names.index(step_name)
        self.segment_states[idx] = True
        if self.segment_active_index == idx:
            self._stop_segment_pulse()
        self._draw_segment_bar()

    def set_current_step(self, step_name):
        if step_name in self.step_names:
            self.segment_active_index = self.step_names.index(step_name)
            self._start_segment_pulse()
        self.update_progress(0, f"Current step: {step_name}")

    def _start_segment_pulse(self):
        if self.segment_pulse_after_id is not None:
            return
        self.segment_pulse_on = False
        self._pulse_active_segment()

    def _stop_segment_pulse(self):
        if self.segment_pulse_after_id is not None:
            try:
                self.root.after_cancel(self.segment_pulse_after_id)
            except Exception:
                pass
        self.segment_pulse_after_id = None
        self.segment_pulse_on = False
        self.segment_active_index = None

    def _pulse_active_segment(self):
        if self.segment_active_index is None:
            self.segment_pulse_after_id = None
            return
        self.segment_pulse_on = not self.segment_pulse_on
        self._draw_segment_bar()
        self.segment_pulse_after_id = self.root.after(500, self._pulse_active_segment)
    
    def count_files(self, directory):
        """Count total files in a directory recursively."""
        total = 0
        for root, dirs, files in os.walk(directory):
            total += len(files)
        return total

    def _file_md5(self, path, chunk=1024 * 1024):
        h = hashlib.md5()
        with open(path, "rb", buffering=0) as f:
            while True:
                data = f.read(chunk)
                if not data:
                    break
                h.update(data)
        return h.hexdigest()

    def _needs_copy_with_md5(self, srcf, dstf, ts_slack=TS_SLACK_SECONDS):
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
        if abs(ss.st_mtime - ds.st_mtime) <= ts_slack:
            return False
        try:
            return self._file_md5(srcf) != self._file_md5(dstf)
        except Exception:
            return True

    def _build_rel_file_map(self, root_dir):
        files = {}
        if not os.path.isdir(root_dir):
            return files
        for root, dirs, names in os.walk(root_dir):
            dirs[:] = [d for d in dirs if not self._is_ignored_path(os.path.join(root, d), root_dir)]
            for name in names:
                full = os.path.join(root, name)
                if self._is_ignored_path(full, root_dir):
                    continue
                rel = os.path.relpath(full, root_dir)
                files[rel] = full
        return files

    def _is_ignored_path(self, path, root_dir):
        rel = os.path.relpath(path, root_dir)
        rel_norm = rel.replace("\\", "/")
        parts = [p for p in rel_norm.split("/") if p and p != "."]
        for part in parts:
            if part in ("__pycache__", "._pycache__"):
                return True
            if part.startswith("._"):
                return True
        base = os.path.basename(path)
        if base.endswith((".pyc", ".pyo")):
            return True
        return False

    def _remove_empty_dirs(self, root_dir):
        if not os.path.isdir(root_dir):
            return
        for root, dirs, files in os.walk(root_dir, topdown=False):
            if dirs or files:
                continue
            try:
                os.rmdir(root)
            except Exception:
                pass

    def remove_stale_files_with_progress(self, src, dst, use_phase=False):
        """Delete files in dst that are not present in src (mirror --delete behavior)."""
        if not os.path.isdir(dst):
            return True

        src_files = self._build_rel_file_map(src)
        dst_files = self._build_rel_file_map(dst)
        stale = [rel for rel in dst_files.keys() if rel not in src_files]
        total_stale = len(stale)
        self.log(f"  Total stale files to delete: {total_stale}")

        removed = 0
        for rel in stale:
            if not self.is_updating:
                return False
            file_path = dst_files.get(rel) or os.path.join(dst, rel)
            try:
                attempt = 0
                while True:
                    try:
                        os.remove(file_path)
                        break
                    except OSError as e:
                        attempt += 1
                        winerr = getattr(e, "winerror", None)
                        if winerr == 483 and attempt < 3:
                            time.sleep(0.5)
                            continue
                        raise
                removed += 1
                time.sleep(COPY_SETTLE_SECONDS)

                percent = (removed / total_stale) * 100 if total_stale else 100
                self.update_progress(removed, f"Removed stale {removed}/{total_stale} files ({percent:.1f}%)")
                if removed % 10 == 0 or removed == total_stale:
                    self.log(f"  [DEL {removed}/{total_stale}] {rel}")
            except Exception as e:
                winerr = getattr(e, "winerror", None)
                if winerr == 483:
                    self.log(f"  ⚠ Device error while deleting stale file {os.path.basename(file_path)}.")
                    self.attempt_chkdsk(file_path)
                    return False
                self.log(f"  ⚠ Failed to delete stale file {rel}: {e}")

        self._remove_empty_dirs(dst)
        return True
    
    def attempt_chkdsk(self, path):
        """Attempt to repair a corrupt filesystem, then prompt user to retry."""
        if sys.platform != 'win32':
            return False
        if self.chkdsk_attempted:
            return False
        drive, _ = os.path.splitdrive(path)
        if not drive:
            return False
        
        self.chkdsk_attempted = True
        self.log(f"Detected filesystem error. Running chkdsk {drive} /f ...")
        try:
            result = subprocess.run(
                ["chkdsk", drive, "/f"],
                capture_output=True,
                text=True,
                timeout=300
            )
            if result.stdout:
                for line in result.stdout.strip().splitlines()[:8]:
                    self.log(f"  [chkdsk] {line}")
            if result.stderr:
                for line in result.stderr.strip().splitlines()[:8]:
                    self.log(f"  [chkdsk] {line}")
        except Exception as e:
            self.log(f"  [chkdsk] Failed to run: {e}")
        
        if 'tk' in sys.modules:
            try:
                root = tk.Tk()
                root.withdraw()
                messagebox.showinfo(
                    "Filesystem Repair",
                    f"CHKDSK was run on {drive}. Please click Update again to retry."
                )
                root.destroy()
            except Exception:
                pass
        return True
    
    def copy_tree_with_progress(self, src, dst, use_phase=False):
        """Copy only changed files (size/mtime fast path with MD5 fallback)."""
        os.makedirs(dst, exist_ok=True)
        src_files = self._build_rel_file_map(src)
        total_files = len(src_files)
        self.log(f"  Total files to verify: {total_files}")

        to_copy = []
        checked = 0
        for rel, src_file in src_files.items():
            if not self.is_updating:
                return False
            dst_file = os.path.join(dst, rel)
            os.makedirs(os.path.dirname(dst_file), exist_ok=True)
            if self._needs_copy_with_md5(src_file, dst_file):
                to_copy.append((rel, src_file, dst_file))
            checked += 1
            if checked % 50 == 0 or checked == total_files:
                percent = (checked / total_files) * 100 if total_files else 100
                self.update_progress(checked, f"Verified {checked}/{total_files} files ({percent:.1f}%)")

        self.log(f"  Changed/new files to copy: {len(to_copy)}")
        copied = 0
        for rel, src_file, dst_file in to_copy:
            if not self.is_updating:
                return False
            try:
                shutil.copy2(src_file, dst_file)
                copied += 1
                time.sleep(COPY_SETTLE_SECONDS)
                percent = (copied / len(to_copy)) * 100 if to_copy else 100
                self.update_progress(copied, f"Copied {copied}/{len(to_copy)} files ({percent:.1f}%)")
                if copied % 10 == 0 or copied == len(to_copy):
                    self.log(f"  [COPY {copied}/{len(to_copy)}] {rel}")
            except Exception as e:
                winerr = getattr(e, "winerror", None)
                if winerr == 483:
                    self.log(f"  ⚠ Device error while copying {os.path.basename(src_file)}.")
                    self.attempt_chkdsk(dst_file)
                    return False
                self.log(f"  ⚠ Failed to copy {os.path.basename(src_file)}: {e}")

        if not to_copy:
            self.log("  No changed files detected.")

        return True
    
    def remove_tree_with_progress(self, directory, use_phase=False):
        """Remove directory tree with progress updates."""
        if not os.path.exists(directory):
            return True
        
        # Count total files
        total_files = self.count_files(directory)
        self.log(f"  Total files to delete: {total_files}")
        
        deleted = 0
        files_to_delete = []
        
        # Collect all files first
        for root, dirs, files in os.walk(directory):
            for file in files:
                files_to_delete.append(os.path.join(root, file))
        
        # Delete files with progress
        for file_path in files_to_delete:
            if not self.is_updating:
                return False
            
            try:
                attempt = 0
                while True:
                    try:
                        os.remove(file_path)
                        break
                    except OSError as e:
                        attempt += 1
                        winerr = getattr(e, "winerror", None)
                        if winerr == 483 and attempt < 3:
                            # Transient device error on removable drives; wait and retry.
                            time.sleep(0.5)
                            continue
                        raise
                deleted += 1
                time.sleep(COPY_SETTLE_SECONDS)
                
                # Update progress
                percent = (deleted / total_files) * 100 if total_files else 100
                self.update_progress(deleted, f"Deleted {deleted}/{total_files} files ({percent:.1f}%)")
                
                # Log every 10th file or last file
                if deleted % 10 == 0 or deleted == total_files:
                    rel_file = os.path.relpath(file_path, directory)
                    self.log(f"  [{deleted}/{total_files}] {rel_file}")
            
            except Exception as e:
                winerr = getattr(e, "winerror", None)
                if winerr == 483:
                    self.log(f"  ⚠ Device error while deleting {os.path.basename(file_path)}. The drive may be corrupted.")
                    self.attempt_chkdsk(file_path)
                    return False
                else:
                    self.log(f"  ⚠ Failed to delete {os.path.basename(file_path)}: {e}")
        
        # Remove empty directories
        for root, dirs, files in os.walk(directory, topdown=False):
            for dir_name in dirs:
                try:
                    os.rmdir(os.path.join(root, dir_name))
                except Exception:
                    pass
        
        # Remove root directory
        try:
            os.rmdir(directory)
        except Exception:
            pass
        
        return True
    
    def get_download_url_and_name(self, locale):
        """Get the download URL and version name based on selected version."""
        import json
        
        version_type = self.selected_version.get()
        
        if version_type == VERSION_MASTER:
            # Master branch
            url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
            name = "master"
            return url, name, False
        
        elif version_type == VERSION_SNAPSHOT:
            # Snapshot branch - try to get pre-release from GitHub API
            try:
                self.log("Fetching latest pre-release information...")
                req = Request(f"{GITHUB_API_URL}/releases", headers={'User-Agent': 'Mozilla/5.0'})
                with self.urlopen_insecure(req, timeout=DOWNLOAD_TIMEOUT) as response:
                    data = json.loads(response.read().decode())
                    # Find first pre-release
                    for release in data:
                        if release.get('prerelease', False):
                            tag_name = release.get('tag_name', '')
                            if tag_name:
                                version = tag_name.split("/", 1)[1] if "/" in tag_name else tag_name
                                asset_name = f"rotorflight-lua-ethos-suite-{version}-{locale}.zip"
                                for asset in release.get("assets", []):
                                    if asset.get("name") == asset_name:
                                        self.log(f"✓ Found latest pre-release asset: {asset_name}")
                                        return asset.get("browser_download_url"), tag_name, True
                                if locale != DEFAULT_LOCALE:
                                    fallback_name = f"rotorflight-lua-ethos-suite-{version}-{DEFAULT_LOCALE}.zip"
                                    for asset in release.get("assets", []):
                                        if asset.get("name") == fallback_name:
                                            self.log(f"⚠ Locale '{locale}' asset not found; using {DEFAULT_LOCALE}")
                                            return asset.get("browser_download_url"), tag_name, True
                                # Fall back to source zip if asset missing
                                url = f"{GITHUB_REPO_URL}/archive/refs/tags/{tag_name}.zip"
                                self.log(f"✓ Found latest pre-release tag: {tag_name} (no asset)")
                                return url, tag_name, False
                    # No pre-release found, fall back to master
                    self.log("⚠ No pre-release found, using master branch")
                    url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
                    name = "master (no snapshot)"
                    return url, name, False
            except Exception as e:
                self.log(f"⚠ Failed to fetch pre-release info: {e}")
                self.log("  Falling back to master branch")
                url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
                name = "master (fallback)"
                return url, name, False
        
        elif version_type == VERSION_RELEASE:
            # Latest release
            try:
                self.log("Fetching latest release information...")
                req = Request(f"{GITHUB_API_URL}/releases/latest", headers={'User-Agent': 'Mozilla/5.0'})
                with self.urlopen_insecure(req, timeout=DOWNLOAD_TIMEOUT) as response:
                    data = json.loads(response.read().decode())
                    tag_name = data.get('tag_name', '')
                    if tag_name:
                        version = tag_name.split("/", 1)[1] if "/" in tag_name else tag_name
                        asset_name = f"rotorflight-lua-ethos-suite-{version}-{locale}.zip"
                        for asset in data.get("assets", []):
                            if asset.get("name") == asset_name:
                                self.log(f"✓ Found latest release asset: {asset_name}")
                                return asset.get("browser_download_url"), tag_name, True
                        if locale != DEFAULT_LOCALE:
                            fallback_name = f"rotorflight-lua-ethos-suite-{version}-{DEFAULT_LOCALE}.zip"
                            for asset in data.get("assets", []):
                                if asset.get("name") == fallback_name:
                                    self.log(f"⚠ Locale '{locale}' asset not found; using {DEFAULT_LOCALE}")
                                    return asset.get("browser_download_url"), tag_name, True
                        # Fall back to source zip if asset missing
                        url = f"{GITHUB_REPO_URL}/archive/refs/tags/{tag_name}.zip"
                        self.log(f"✓ Found latest release tag: {tag_name} (no asset)")
                        return url, tag_name, False
                    else:
                        raise RuntimeError("No tag_name in release data")
            except Exception as e:
                self.log(f"⚠ Failed to fetch release info: {e}")
                self.log("  Falling back to master branch")
                url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
                name = "master (fallback)"
                return url, name, False
        
        # Default fallback
        url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
        name = "master"
        return url, name, False

    def is_git_available(self):
        """Check if git is available."""
        try:
            result = subprocess.run(
                ["git", "--version"],
                capture_output=True,
                text=True,
                timeout=5,
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
            )
            return result.returncode == 0
        except Exception:
            return False

    def sparse_checkout_master(self, dest_dir, locale):
        """Use persistent sparse master cache, then stage required folders into dest_dir."""
        if not self.is_git_available():
            self.log("⚠ Git not available; falling back to ZIP download")
            return False

        cache_repo = WORK_DIR / CACHE_DIRNAME / "master_sparse_repo"
        os.makedirs(cache_repo, exist_ok=True)
        self.log(f"Using git sparse cache for master: {cache_repo}")

        def run_git(args, cwd, timeout=60, progress_cb=None):
            cmd = ["git"] + args
            self.log(f"  Git: {' '.join(cmd)}")
            if "fetch" in args and progress_cb:
                output_lines = []
                try:
                    proc = subprocess.Popen(
                        cmd,
                        cwd=cwd,
                        stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT,
                        text=True,
                        bufsize=1,
                        universal_newlines=True,
                        creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
                    )
                    percent_re = re.compile(r"(\\d+)%")
                    last_percent = -1
                    for line in iter(proc.stdout.readline, ""):
                        if not line:
                            break
                        output_lines.append(line)
                        line_stripped = line.strip()
                        if line_stripped:
                            self.log(f"    [git] {line_stripped}")
                        m = percent_re.search(line_stripped)
                        if m:
                            pct = int(m.group(1))
                            if pct > last_percent:
                                last_percent = pct
                                progress_cb(pct)
                    proc.wait(timeout=timeout)
                    return subprocess.CompletedProcess(cmd, proc.returncode, stdout="".join(output_lines), stderr="")
                except subprocess.TimeoutExpired as e:
                    try:
                        proc.kill()
                    except Exception:
                        pass
                    return subprocess.CompletedProcess(cmd, 1, stdout="".join(output_lines), stderr=str(e))
            else:
                result = subprocess.run(
                    cmd,
                    cwd=cwd,
                    capture_output=True,
                    text=True,
                    timeout=timeout,
                    creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0
                )
                if result.stdout:
                    for line in result.stdout.strip().splitlines():
                        if line.strip():
                            self.log(f"    [git] {line}")
                if result.stderr:
                    for line in result.stderr.strip().splitlines():
                        if line.strip():
                            self.log(f"    [git] {line}")
                return result

        git_dir = os.path.join(cache_repo, ".git")
        if not os.path.isdir(git_dir):
            init = run_git(["init"], cwd=str(cache_repo))
            if init.returncode != 0:
                self.log(f"⚠ Git init failed: {init.stderr.strip()}")
                return False
            add_origin = run_git(["remote", "add", "origin", GITHUB_REPO_URL + ".git"], cwd=str(cache_repo))
            if add_origin.returncode != 0:
                self.log(f"⚠ Git remote add failed: {add_origin.stderr.strip()}")
                return False

        run_git(["config", "core.sparseCheckout", "true"], cwd=str(cache_repo))
        run_git(["config", "advice.detachedHead", "false"], cwd=str(cache_repo))

        sparse_file = os.path.join(cache_repo, ".git", "info", "sparse-checkout")
        os.makedirs(os.path.dirname(sparse_file), exist_ok=True)
        with open(sparse_file, "w", encoding="utf-8") as f:
            f.write("src/rfsuite/\n")
            f.write(".vscode/scripts/\n")
            f.write("bin/sound-generator/soundpack/\n")

        fetch = run_git(
            ["fetch", "--depth", "1", "--progress", "origin", "master"],
            cwd=str(cache_repo),
            timeout=180,
            progress_cb=lambda pct: self.update_progress(pct, f"Fetching master... {pct}%")
        )
        cache_ready = False
        if fetch.returncode != 0:
            self.log(f"⚠ Git fetch failed: {fetch.stderr.strip()}")
            if os.path.isdir(os.path.join(cache_repo, "src", TARGET_NAME)):
                self.log("⚠ Using previously cached master snapshot.")
                cache_ready = True
            else:
                return False
        else:
            checkout = run_git(["checkout", "-f", "FETCH_HEAD"], cwd=str(cache_repo))
            if checkout.returncode != 0:
                self.log(f"⚠ Git checkout failed: {checkout.stderr.strip()}")
                if not os.path.isdir(os.path.join(cache_repo, "src", TARGET_NAME)):
                    return False
            else:
                cache_ready = True

        if not cache_ready and not os.path.isdir(os.path.join(cache_repo, "src", TARGET_NAME)):
            self.log("⚠ Sparse cache does not contain required source tree.")
            return False

        if os.path.isdir(dest_dir):
            shutil.rmtree(dest_dir, ignore_errors=True)
        os.makedirs(dest_dir, exist_ok=True)

        staged_paths = [
            "src/rfsuite",
            ".vscode/scripts",
            "bin/sound-generator/soundpack",
        ]
        for rel in staged_paths:
            src_path = os.path.join(cache_repo, rel)
            dst_path = os.path.join(dest_dir, rel)
            if not os.path.exists(src_path):
                if rel == "src/rfsuite":
                    self.log(f"⚠ Missing required path in cache: {rel}")
                    return False
                self.log(f"⚠ Optional path missing in cache: {rel}")
                continue
            os.makedirs(os.path.dirname(dst_path), exist_ok=True)
            if os.path.isdir(src_path):
                def _ignore_ephemeral(_dir, names):
                    ignored = []
                    for n in names:
                        if n in ("__pycache__", "._pycache__"):
                            ignored.append(n)
                            continue
                        if n.startswith("._"):
                            ignored.append(n)
                            continue
                        if n.endswith((".pyc", ".pyo")):
                            ignored.append(n)
                    return ignored

                shutil.copytree(src_path, dst_path, dirs_exist_ok=True, ignore=_ignore_ephemeral)
            else:
                shutil.copy2(src_path, dst_path)

        self.log("✓ Sparse checkout cache updated and staged")
        return True

    def copy_sound_pack(self, repo_dir, dest_dir, locale, use_phase=False):
        """Copy sound pack for selected locale into destination tree."""
        locale = locale or DEFAULT_LOCALE
        if locale == DEFAULT_LOCALE:
            self.log(f"  Audio pack '{DEFAULT_LOCALE}' already included; skipping copy")
            return True
        src = os.path.join(repo_dir, "bin", "sound-generator", "soundpack", locale)
        self.log(f"  Audio source: {src}")
        if not os.path.isdir(src):
            self.log(f"⚠ Sound pack for '{locale}' not found; default audio already included, skipping copy")
            return False

        dest = os.path.join(dest_dir, "audio", locale)
        try:
            os.makedirs(dest, exist_ok=True)
            self.log(f"  Copying audio pack to: {dest}")
            src_files = self._build_rel_file_map(src)
            dst_files = self._build_rel_file_map(dest)

            stale = [rel for rel in dst_files.keys() if rel not in src_files]
            if stale:
                self.log(f"  Removing stale audio files: {len(stale)}")
                removed = 0
                for rel in stale:
                    p = dst_files.get(rel) or os.path.join(dest, rel)
                    try:
                        os.remove(p)
                        removed += 1
                        if removed % 10 == 0 or removed == len(stale):
                            self.log(f"  [AUDIO-DEL {removed}/{len(stale)}] {rel}")
                    except FileNotFoundError:
                        pass
                    except Exception as e:
                        self.log(f"  ⚠ Failed to remove stale audio {rel}: {e}")
                self._remove_empty_dirs(dest)

            to_copy = []
            for rel, src_file in src_files.items():
                dst_file = os.path.join(dest, rel)
                os.makedirs(os.path.dirname(dst_file), exist_ok=True)
                if self._needs_copy_with_md5(src_file, dst_file):
                    to_copy.append((rel, src_file, dst_file))

            copied = 0
            total_files = len(to_copy)
            for rel, src_file, dst_file in to_copy:
                shutil.copy2(src_file, dst_file)
                copied += 1
                percent = (copied / total_files) * 100 if total_files else 100
                if use_phase:
                    self.update_progress(copied, f"Audio {copied}/{total_files} files ({percent:.1f}%)")
                if copied % 10 == 0 or copied == total_files:
                    self.log(f"  [AUDIO {copied}/{total_files}] {rel}")
                time.sleep(COPY_SETTLE_SECONDS)

            self.log(f"✓ Audio pack copied: {locale}")
            return True
        except Exception as e:
            # On Windows, hardware/device I/O errors should abort the update.
            if sys.platform == "win32" and getattr(e, "winerror", None) is not None:
                raise RuntimeError(f"Audio pack copy failed due to Windows device error: {e}") from e
            self.log(f"⚠ Failed to copy audio pack: {e}")
            return False

    def locate_source_dir(self, extract_dir):
        """Locate the rfsuite source directory in extracted content."""
        possible_paths = [
            os.path.join(extract_dir, "scripts", TARGET_NAME),  # prebuilt asset layout
            os.path.join(extract_dir, "src", TARGET_NAME),      # repo layout
            os.path.join(extract_dir, TARGET_NAME),             # direct
        ]
        for path in possible_paths:
            if os.path.isdir(path):
                return path
        return None

    def get_master_commit_suffix(self):
        """Fetch the latest master commit SHA and return commit-<sha7>."""
        import json
        try:
            req = Request(f"{GITHUB_API_URL}/commits/master", headers={'User-Agent': 'Mozilla/5.0'})
            with self.urlopen_insecure(req, timeout=DOWNLOAD_TIMEOUT) as response:
                data = json.loads(response.read().decode())
                sha = data.get("sha", "")
                if sha:
                    return f"commit-{sha[:7]}"
        except Exception as e:
            self.log(f"⚠ Failed to fetch master commit SHA: {e}")
        return "master"

    def derive_version_suffix(self, version_type, version_name):
        """Derive the version suffix to write into main.lua based on workflows."""
        # Strip common tag prefixes
        if version_name.startswith("release/"):
            return version_name.split("/", 1)[1]
        if version_name.startswith("snapshot/"):
            return version_name.split("/", 1)[1]
        if version_type == VERSION_MASTER:
            return self.get_master_commit_suffix()
        # Fallback: use a sanitized first token
        return (version_name.split()[0] if version_name else "master")

    def update_main_lua_version(self, main_lua_path, version_suffix):
        """Update the version suffix in main.lua."""
        try:
            with open(main_lua_path, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception as e:
            self.log(f"⚠ Unable to read main.lua for version update: {e}")
            return False

        pattern = re.compile(r'(version\s*=\s*\{[^}]*suffix\s*=\s*")([^"]*)(")', re.S)
        if not pattern.search(content):
            self.log("⚠ Version suffix pattern not found in main.lua")
            return False

        updated = pattern.sub(lambda m: f"{m.group(1)}{version_suffix}{m.group(3)}", content)
        try:
            with open(main_lua_path, "w", encoding="utf-8") as f:
                f.write(updated)
            self.log(f"✓ Updated main.lua version suffix to '{version_suffix}'")
            return True
        except Exception as e:
            self.log(f"⚠ Unable to write main.lua version update: {e}")
            return False

    def read_main_lua_version(self, main_lua_path):
        """Read the full version string from main.lua."""
        try:
            with open(main_lua_path, "r", encoding="utf-8") as f:
                content = f.read()
        except Exception as e:
            self.log(f"⚠ Unable to read main.lua for version info: {e}")
            return None

        pattern = re.compile(
            r'version\s*=\s*\{[^}]*major\s*=\s*(\d+)[^}]*minor\s*=\s*(\d+)[^}]*revision\s*=\s*(\d+)[^}]*suffix\s*=\s*"([^"]+)"',
            re.S
        )
        match = pattern.search(content)
        if not match:
            self.log("⚠ Could not parse version fields from main.lua")
            return None

        major, minor, revision, suffix = match.groups()
        prefix = f"{major}.{minor}.{revision}-"
        if suffix.startswith(prefix):
            return suffix
        return f"{major}.{minor}.{revision}-{suffix}"
    
    def start_update(self):
        """Start the update process in a background thread."""
        if self.is_updating:
            return
        
        _ensure_work_dir()
        self.is_updating = True
        self.update_button.config(state=tk.DISABLED)
        self.cancel_button.config(state=tk.NORMAL)
        self.reset_steps()
        self.update_progress(0, "Starting...")
        
        self.update_thread = threading.Thread(target=self.update_process, daemon=True)
        self.update_thread.start()
    
    def cancel_update(self):
        """Cancel the update process."""
        self.is_updating = False
        self.log("Update cancelled by user")
        self.set_status("Update cancelled")
        self._stop_segment_pulse()
        self.update_progress(0, "")
        self.update_button.config(state=tk.NORMAL)
        self.cancel_button.config(state=tk.DISABLED)
    
    def update_process(self):
        """Main update process (runs in background thread)."""
        try:
            self.update_progress(0, "Starting...")

            # Step 1: Check if radio is already mounted (storage mode)
            self.set_status("Looking for radio...")
            self.set_current_step("Find")
            self.log("Checking if radio is already in storage mode...")
            
            scripts_dir = None
            radio_already_mounted = False
            
            # Try to find the radio drive first
            try:
                scripts_dir = self.radio.get_scripts_dir()
                if scripts_dir:
                    radio_already_mounted = True
                    self.log("✓ Radio already in storage mode")
                    self.log(f"  Found scripts directory: {scripts_dir}")
            except Exception:
                pass
            
            if not scripts_dir:
                scripts_dir = self.radio.find_scripts_dir_on_drives(removable_only=True)
                if scripts_dir:
                    radio_already_mounted = True
                    self.log("✓ Found scripts directory on removable drive")
                    self.log(f"  Found scripts directory: {scripts_dir}")
            
            if not self.is_updating:
                return

            if radio_already_mounted:
                self.mark_step_done("Find")
                self.set_current_step("Connect")
                self.mark_step_done("Connect")
            
            # Step 2: If not mounted, try to connect via HID and switch mode
            if not radio_already_mounted:
                self.set_status("Connecting to radio...")
                self.set_current_step("Connect")
                self.log("Radio not in storage mode, attempting to connect via USB HID...")
                
                try:
                    self.radio.connect()
                    self.log("✓ Radio connected via USB HID")
                except Exception as e:
                    self.log(f"✗ Failed to connect to radio: {e}")
                    self.log("Attempting fallback: scanning all drives for scripts folder...")
                    scripts_dir = self.radio.find_scripts_dir_on_drives(removable_only=False)
                    if scripts_dir:
                        radio_already_mounted = True
                        self.log("✓ Found scripts directory on drive")
                        self.log(f"  Found scripts directory: {scripts_dir}")
                        self.mark_step_done("Find")
                        self.mark_step_done("Connect")
                    else:
                        self.log("No scripts directory found on any drive.")
                    self.log("Please check the radio connection:")
                    self.log("  - USB cable is connected and data-capable")
                    self.log("  - Radio is powered on")
                    self.log("  - Radio is in debug mode (will be switched automatically) or storage mode (mounted as a drive)")
                    if not radio_already_mounted:
                        raise RuntimeError("Radio not detected. Please plug in your radio and try again.") from e
                
                if not self.is_updating:
                    return
                
                # Step 3: Switch to storage mode
                self.set_status("Switching to storage mode...")
                self.log("Switching radio to storage mode...")
                
                try:
                    self.radio.switch_to_storage_mode()
                    self.log("✓ Switched to storage mode")
                except Exception as e:
                    self.log(f"✗ Failed to switch mode: {e}")
                    raise
                
                if not self.is_updating:
                    return
            
            # Step 4: Wait for drive to mount (if we just switched modes)
            if not radio_already_mounted:
                self.set_status("Waiting for drive to mount...")
                self.log("Waiting for radio drive to mount...")
            
                scripts_dir = None
                for attempt in range(10):
                    if not self.is_updating:
                        return
                    
                    scripts_dir = self.radio.get_scripts_dir()
                    if scripts_dir:
                        break
                    
                    time.sleep(1)
                    self.log(f"  Attempt {attempt + 1}/10...")
                
                if not scripts_dir:
                    self.log("✗ Radio drive not found.")
                    self.log("Please confirm the radio is in storage mode and mounted as a drive.")
                    self.log("If needed, unplug/replug USB or power-cycle the radio.")
                    raise RuntimeError("Could not find radio scripts directory")
                
                self.log(f"✓ Found scripts directory: {scripts_dir}")
                self.mark_step_done("Find")
                self.mark_step_done("Connect")
            else:
                # Radio was already mounted, scripts_dir is already set
                self.log("Skipping mount wait (radio already mounted)")
                self.mark_step_done("Find")
                self.mark_step_done("Connect")
            
            if not self.is_updating:
                return
            
            # Step 5: Download suite from GitHub (or git sparse checkout for master)
            self.set_status("Preparing download...")
            self.set_current_step("Download")

            version_type = self.selected_version.get()
            version_name = "master" if version_type == VERSION_MASTER else ""
            version_suffix = self.derive_version_suffix(version_type, version_name)
            locale = self.selected_locale.get() or DEFAULT_LOCALE
            self.log(f"Selected version: {version_name or version_type}")
            self.log(f"Selected locale: {locale}")
            self.log(f"Version suffix for main.lua: {version_suffix}")
            is_asset = False
            
            _ensure_work_dir()
            temp_dir = tempfile.mkdtemp(prefix="rfsuite-update-", dir=str(WORK_DIR))
            zip_path = None

            # For master, prefer sparse checkout to avoid full repo download
            repo_dir = None
            if version_type == VERSION_MASTER:
                self.set_status("Fetching master via git...")
                self.update_progress(0, "Fetching master via git...")
                self.log("Git sparse checkout: src/rfsuite/, .vscode/scripts/, bin/sound-generator/soundpack/")
                repo_dir = os.path.join(temp_dir, "repo")
                if not self.sparse_checkout_master(repo_dir, locale):
                    repo_dir = None
                else:
                    self.log("✓ Using sparse checkout; skipping ZIP download")
                    self.mark_step_done("Download")

            if repo_dir is None:
                # Get download URL based on selected version (release/snapshot or master fallback)
                download_url, version_name, is_asset = self.get_download_url_and_name(locale)
                if not download_url:
                    raise RuntimeError("No download URL available")
                if version_type != VERSION_MASTER:
                    version_suffix = self.derive_version_suffix(version_type, version_name)
                    self.log(f"Selected version: {version_name}")
                    self.log(f"Version suffix for main.lua: {version_suffix}")
                self.log(f"Downloading from: {download_url}")
                try:
                    zip_path = self._download_zip_with_cache(download_url)
                    if not zip_path:
                        return
                    self.mark_step_done("Download")
                except (URLError, HTTPError) as e:
                    self.log(f"✗ Download failed: {e}")
                    raise
            
            if not self.is_updating:
                return
            
            # Step 6: Extract archive (if we downloaded a zip)
            extract_dir = None
            if repo_dir is None:
                self.set_status("Extracting archive...")
                self.set_current_step("Extract")
                self.log("Extracting downloaded archive...")

                extract_dir = os.path.join(temp_dir, "extracted")

                try:
                    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                        zip_ref.extractall(extract_dir)
                    self.log("✓ Archive extracted")
                    self.mark_step_done("Extract")
                except Exception as e:
                    self.log(f"✗ Extraction failed: {e}")
                    raise
            else:
                self.mark_step_done("Extract")
            
            if not self.is_updating:
                return
            
            # Step 7: Find source directory
            self.log("Locating source files...")

            if repo_dir is None:
                # GitHub creates a folder like "rotorflight-lua-ethos-suite-master"
                extracted_items = os.listdir(extract_dir)
                if not extracted_items:
                    raise RuntimeError("Extracted archive is empty")
                repo_dir = os.path.join(extract_dir, extracted_items[0])

            src_dir = self.locate_source_dir(repo_dir)
            if src_dir:
                self.log(f"✓ Found source: {os.path.relpath(src_dir, repo_dir)}")
            
            if not src_dir:
                self.log(f"✗ Source directory not found in any of these locations:")
                for path in [
                    os.path.join(repo_dir, "scripts", TARGET_NAME),
                    os.path.join(repo_dir, "src", TARGET_NAME),
                    os.path.join(repo_dir, TARGET_NAME),
                ]:
                    self.log(f"  - {os.path.relpath(path, repo_dir)}")
                raise RuntimeError(f"Could not find {TARGET_NAME} in extracted archive")
            
            if not self.is_updating:
                return
            
            # Step 8: Compile i18n translations (master only) BEFORE copying to radio
            if version_type == VERSION_MASTER:
                self.log("Preparing translation compiler (this can take a moment)...")
                self.set_status("Compiling translations...")
                self.log("Compiling i18n translations...")
                self.set_current_step("Translate")

                try:
                    # Find i18n JSON file in the extracted repo (try multiple locations)
                    i18n_json = None
                    locale = self.selected_locale.get() or DEFAULT_LOCALE
                    for base_path in [
                        os.path.join(repo_dir, "src", TARGET_NAME, "i18n", f"{locale}.json"),
                        os.path.join(repo_dir, "scripts", TARGET_NAME, "i18n", f"{locale}.json"),
                        os.path.join(repo_dir, TARGET_NAME, "i18n", f"{locale}.json"),
                        os.path.join(repo_dir, "src", TARGET_NAME, "i18n", f"{DEFAULT_LOCALE}.json"),
                        os.path.join(repo_dir, "scripts", TARGET_NAME, "i18n", f"{DEFAULT_LOCALE}.json"),
                        os.path.join(repo_dir, TARGET_NAME, "i18n", f"{DEFAULT_LOCALE}.json"),
                    ]:
                        if os.path.isfile(base_path):
                            i18n_json = base_path
                            break

                    if i18n_json and os.path.isfile(i18n_json):
                        self.log(f"  Using i18n JSON: {os.path.basename(i18n_json)}")
                        self.log("  Running embedded i18n compiler...")
                        compile_i18n_tags(i18n_json, src_dir, self.log)
                        self.log("OK i18n translations compiled successfully")
                        self.mark_step_done("Translate")
                    else:
                        self.log("WARN i18n files not found, skipping translation compilation")
                        if i18n_json:
                            self.log(f"  Missing: {i18n_json}")
                except Exception as e:
                    self.log(f"WARN i18n compilation error: {e}")
                    self.mark_step_done("Translate")
            else:
                self.mark_step_done("Translate")

            if not self.is_updating:
                return

            # Step 9: Copy files to radio
            dest_dir = os.path.join(scripts_dir, TARGET_NAME)
            self.log("Syncing files to radio...")

            # Single visible phase: Copy (includes stale prune + changed-file copy)
            self.set_current_step("Copy")
            self.set_status("Removing stale files...")
            if not self.remove_stale_files_with_progress(src_dir, dest_dir, use_phase=True):
                self.log("⚠ Stale cleanup cancelled")
                return
            
            if not self.is_updating:
                return
            
            # Copy only changed files
            self.log("  Copying changed files...")
            self.set_status("Copying files to radio...")
            if not self.copy_tree_with_progress(src_dir, dest_dir, use_phase=True):
                self.log("⚠ Copy cancelled")
                return
            self.mark_step_done("Copy")
            
            self.log(f"✓ Files synced to radio successfully")

            self.set_status("Finalizing installation...")

            # Ensure audio pack matches selected locale for master/zip builds
            self.set_current_step("Audio")
            if not is_asset:
                self.log("Updating audio pack...")
                self.copy_sound_pack(repo_dir, dest_dir, locale, use_phase=True)
                self.mark_step_done("Audio")
            else:
                self.mark_step_done("Audio")

            # Update main.lua version suffix only for master (release/snapshot assets already stamped)
            main_lua_path = os.path.join(dest_dir, "main.lua")
            if version_type == VERSION_MASTER:
                if os.path.isfile(main_lua_path):
                    self.update_main_lua_version(main_lua_path, version_suffix)
                else:
                    self.log(f"⚠ main.lua not found at {main_lua_path} for version update")
            
            if not self.is_updating:
                return
            
            # Step 11: Cleanup
            self.log("Final cleanup...")
            self.set_status("Cleaning up...")
            self.log("Cleaning up temporary files...")
            self.set_current_step("Cleanup")
            try:
                shutil.rmtree(temp_dir)
            except Exception:
                pass
            self.mark_step_done("Cleanup")
            
            # Success!
            self.set_status("Update completed successfully!")
            self.progress_label.config(text="")
            self._stop_segment_pulse()
            self.log("")
            self.log("=" * 50)
            self.log("✓ UPDATE COMPLETED SUCCESSFULLY!")
            self.log("=" * 50)
            self.log("")
            full_version = self.read_main_lua_version(main_lua_path) if 'main_lua_path' in locals() else None
            if full_version:
                self.log(f"Installed version: {full_version}")
            else:
                self.log(f"Installed version suffix: {version_suffix}")
            self.log("You can now disconnect your radio and restart it.")
            self.log("The new Rotorflight Lua Ethos Suite is ready to use.")
            
            messagebox.showinfo(
                "Update Complete",
                "Rotorflight Lua Ethos Suite has been updated successfully!\n\n"
                "You can now disconnect and restart your radio."
            )
            
        except Exception as e:
            self.set_status("Update failed")
            self.log("")
            self.log("=" * 50)
            self.log(f"✗ UPDATE FAILED: {e}")
            self.log("=" * 50)
            
            messagebox.showerror(
                "Update Failed",
                f"The update process failed:\n\n{e}\n\n"
                "Please check the log for details."
            )
        
        finally:
            self.is_updating = False
            self._stop_segment_pulse()
            self.update_button.config(state=tk.NORMAL)
            self.cancel_button.config(state=tk.DISABLED)
            
            # Disconnect from radio
            try:
                self.radio.disconnect()
            except Exception:
                pass


def check_dependencies():
    """Check if required dependencies are installed."""
    missing = []
    optional = []
    
    if hid is None:
        optional.append("hidapi (install with: pip install hidapi)")
    
    if sys.platform == 'win32' and (win32api is None or win32file is None):
        missing.append("pywin32 (install with: pip install pywin32)")
    
    if missing:
        msg = "Missing required dependencies:\n\n" + "\n".join(f"  • {dep}" for dep in missing)
        msg += "\n\nPlease install them and try again."
        
        if 'tk' in sys.modules:
            root = tk.Tk()
            root.withdraw()
            messagebox.showerror("Missing Dependencies", msg)
            root.destroy()
        else:
            print(msg)
        
        return False

    if optional:
        msg = "Optional dependencies missing:\n\n" + "\n".join(f"  • {dep}" for dep in optional)
        msg += "\n\nHID features will be unavailable, but storage-mode updates can still work."
        if 'tk' in sys.modules:
            root = tk.Tk()
            root.withdraw()
            messagebox.showwarning("Optional Dependencies", msg)
            root.destroy()
        else:
            print(msg)
    
    return True


def main():
    """Main entry point."""
    try:
        # Single-instance guard
        if os.path.exists(UPDATER_LOCK_FILE):
            try:
                if 'tk' in sys.modules:
                    root = tk.Tk()
                    root.withdraw()
                    messagebox.showinfo("Updater Running", "The updater is already running.")
                    root.destroy()
            except Exception:
                pass
            sys.exit(0)
        with open(UPDATER_LOCK_FILE, "w", encoding="utf-8") as f:
            f.write(str(os.getpid()))
        atexit.register(lambda: os.path.exists(UPDATER_LOCK_FILE) and os.remove(UPDATER_LOCK_FILE))

        if not check_dependencies():
            sys.exit(1)
        
        root = tk.Tk()
        app = UpdaterGUI(root)
        def on_close():
            root.destroy()
        root.protocol("WM_DELETE_WINDOW", on_close)
        root.mainloop()
    except Exception:
        error_log = WORK_DIR / "updater_error.log"
        with open(error_log, "w", encoding="utf-8") as f:
            f.write(traceback.format_exc())
        try:
            if 'tk' in sys.modules:
                root = tk.Tk()
                root.withdraw()
                messagebox.showerror(
                    "Updater Error",
                    f"Updater failed to start.\n\nDetails written to:\n{error_log}"
                )
                root.destroy()
        except Exception:
            pass
        sys.exit(1)


if __name__ == "__main__":
    main()
