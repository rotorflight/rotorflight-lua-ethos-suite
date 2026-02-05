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
import webbrowser
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError
import atexit

# GUI imports
try:
    import tkinter as tk
    from tkinter import ttk, scrolledtext, messagebox
except ImportError:
    print("Error: tkinter is required but not found.")
    sys.exit(1)

# HID imports for radio communication
try:
    import hid
except ImportError:
    print("Warning: hid module not found. Install with: pip install hidapi")
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
AVAILABLE_LOCALES = ["en", "de", "es", "fr", "it", "nl"]
DOWNLOAD_TIMEOUT = 120
DOWNLOAD_RETRIES = 3
DOWNLOAD_RETRY_DELAY = 2
COPY_SETTLE_SECONDS = 0.02
LOGO_URL = "https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/bin/updater/src/logo.png"
UPDATER_VERSION = "0.0.0"
UPDATER_RELEASE_JSON_URL = "https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/bin/updater/src/release.json"
UPDATER_INFO_URL = "https://github.com/rotorflight/rotorflight-lua-ethos-suite/tree/master/bin/updater/"
UPDATER_LOCK_FILE = os.path.join(tempfile.gettempdir(), "rfsuite_updater.lock")

# Version types
VERSION_RELEASE = "release"
VERSION_SNAPSHOT = "snapshot"
VERSION_MASTER = "master"

# USB Mode Request Commands
ETHOS_SUITE_USB_MODE_REQUEST = 0x81
USB_MODE_STORAGE = 0x69  # Stop debug mode = enable storage mode
USB_MODE_DEBUG = 0x68    # Start debug mode


class RadioInterface:
    """Interface to communicate with Ethos radio via USB HID."""
    
    def __init__(self):
        self.device = None
        self.drives = {}
    
    def connect(self):
        """Connect to the Ethos radio."""
        if hid is None:
            raise RuntimeError("hidapi module not available. Install with: pip install hidapi")
        
        try:
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
            for base in ["/Volumes", "/media", "/mnt"]:
                if not os.path.isdir(base):
                    continue
                try:
                    for entry in os.listdir(base):
                        root = os.path.join(base, entry)
                        for key in ('flash', 'sdcard', 'radio'):
                            marker = os.path.join(root, key + ".cpuid")
                            if os.path.exists(marker):
                                self.drives[key] = root
                except Exception:
                    continue
        
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


class UpdaterGUI:
    """Main GUI application for updating the radio."""
    
    def __init__(self, root):
        self.root = root
        self.root.title("Rotorflight Lua Ethos Suite Updater")
        self.root.geometry("700x680")
        self.root.resizable(True, True)
        
        self.radio = RadioInterface()
        self.update_thread = None
        self.is_updating = False
        self.selected_version = tk.StringVar(value=VERSION_RELEASE)
        self.selected_locale = tk.StringVar(value=DEFAULT_LOCALE)
        
        self.setup_ui()
    
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
                target_h = 70
                target_w = 320
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
                self.logo_label.place(relx=1.0, x=0, y=0, anchor=tk.NE)
                subtitle_right.place(relx=1.0, x=-6, y=52, anchor=tk.NE)
                subtitle_right.lift()
            except Exception:
                pass

        # Async fetch logo to avoid blocking UI
        def fetch_logo():
            try:
                req = Request(LOGO_URL, headers={'User-Agent': 'Mozilla/5.0'})
                with self.urlopen_insecure(req, timeout=10) as response:
                    logo_bytes = response.read()
                tmp_logo = Path(tempfile.gettempdir()) / "rfsuite_logo.png"
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

        # Updater update notification (hidden by default)
        self.update_notice = ttk.Frame(self.root, padding="8")
        self.update_notice.pack(fill=tk.X, padx=10, pady=(0, 5))
        self.update_notice.pack_forget()

        self.update_notice_label = ttk.Label(
            self.update_notice,
            text="",
            font=("Arial", 9)
        )
        self.update_notice_label.pack(side=tk.LEFT)

        self.update_notice_button = ttk.Button(
            self.update_notice,
            text="Open Download Page",
            command=lambda: webbrowser.open(UPDATER_INFO_URL)
        )
        self.update_notice_button.pack(side=tk.RIGHT)
        
        # Status frame
        status_frame = ttk.LabelFrame(self.root, text="Status", padding="10")
        status_frame.pack(fill=tk.X, padx=10, pady=5)
        
        self.status_label = ttk.Label(
            status_frame,
            text="Ready to update",
            font=("Arial", 10)
        )
        self.status_label.pack()
        
        # Progress bar
        self.progress = ttk.Progressbar(
            status_frame,
            mode='indeterminate',
            length=300
        )
        self.progress.pack(pady=5)
        
        # Progress label (shows file count during operations)
        self.progress_label = ttk.Label(
            status_frame,
            text="",
            font=("Arial", 8)
        )
        self.progress_label.pack()
        
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
        
        ttk.Button(
            button_frame,
            text="Exit",
            command=self.root.quit
        ).pack(side=tk.RIGHT, padx=5)
        
        # Info frame
        info_frame = ttk.Frame(self.root, padding="10")
        info_frame.pack(fill=tk.X)
        
        info_text = (
            "Instructions:\n"
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
            if remote_version and self._is_newer_version(UPDATER_VERSION, remote_version):
                msg = f"Updater {remote_version} is available (current {UPDATER_VERSION})."
                self.root.after(0, lambda: self.show_update_notice(msg, remote_url))
        except Exception:
            pass

    def show_update_notice(self, message, url):
        self.update_notice_label.config(text=message)
        self.update_notice_button.config(command=lambda: webbrowser.open(url))
        self.update_notice.pack(fill=tk.X, padx=10, pady=(0, 5))
    
    def set_status(self, message):
        """Update the status label."""
        self.status_label.config(text=message)
        self.root.update_idletasks()
    
    def set_progress_mode(self, mode='indeterminate', maximum=100):
        """Set progress bar mode."""
        self.progress.stop()
        self.progress.config(mode=mode, maximum=maximum, value=0)
        if mode == 'indeterminate':
            self.progress.start()
            self.progress_label.config(text="")
        self.root.update_idletasks()
    
    def update_progress(self, value, text=""):
        """Update progress bar value and label."""
        self.progress.config(value=value)
        self.progress_label.config(text=text)
        self.root.update_idletasks()
    
    def count_files(self, directory):
        """Count total files in a directory recursively."""
        total = 0
        for root, dirs, files in os.walk(directory):
            total += len(files)
        return total
    
    def copy_tree_with_progress(self, src, dst):
        """Copy directory tree with progress updates."""
        # Count total files
        total_files = self.count_files(src)
        self.log(f"  Total files to copy: {total_files}")
        
        # Switch to determinate progress
        self.set_progress_mode('determinate', maximum=total_files)
        
        copied = 0
        for root, dirs, files in os.walk(src):
            # Create destination directory structure
            rel_path = os.path.relpath(root, src)
            dst_dir = os.path.join(dst, rel_path) if rel_path != '.' else dst
            os.makedirs(dst_dir, exist_ok=True)
            
            # Copy files
            for file in files:
                if not self.is_updating:
                    return False
                
                src_file = os.path.join(root, file)
                dst_file = os.path.join(dst_dir, file)
                
                try:
                    shutil.copy2(src_file, dst_file)
                    copied += 1
                    time.sleep(COPY_SETTLE_SECONDS)
                    
                    # Update progress
                    percent = (copied / total_files) * 100
                    self.update_progress(copied, f"Copied {copied}/{total_files} files ({percent:.1f}%)")
                    
                    # Log every 10th file or last file
                    if copied % 10 == 0 or copied == total_files:
                        rel_file = os.path.relpath(src_file, src)
                        self.log(f"  [{copied}/{total_files}] {rel_file}")
                
                except Exception as e:
                    self.log(f"  ⚠ Failed to copy {file}: {e}")
        
        return True
    
    def remove_tree_with_progress(self, directory):
        """Remove directory tree with progress updates."""
        if not os.path.exists(directory):
            return True
        
        # Count total files
        total_files = self.count_files(directory)
        self.log(f"  Total files to delete: {total_files}")
        
        # Switch to determinate progress
        self.set_progress_mode('determinate', maximum=total_files)
        
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
                os.remove(file_path)
                deleted += 1
                
                # Update progress
                percent = (deleted / total_files) * 100
                self.update_progress(deleted, f"Deleted {deleted}/{total_files} files ({percent:.1f}%)")
                
                # Log every 10th file or last file
                if deleted % 10 == 0 or deleted == total_files:
                    rel_file = os.path.relpath(file_path, directory)
                    self.log(f"  [{deleted}/{total_files}] {rel_file}")
            
            except Exception as e:
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
        """Sparse checkout required folders from master into dest_dir."""
        if not self.is_git_available():
            self.log("⚠ Git not available; falling back to ZIP download")
            return False

        self.log("Using git sparse checkout for master...")
        os.makedirs(dest_dir, exist_ok=True)

        def run_git(args, timeout=60):
            cmd = ["git"] + args
            self.log(f"  Git: {' '.join(cmd)}")
            result = subprocess.run(
                cmd,
                cwd=dest_dir,
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

        # Initialize repository and configure sparse checkout
        init = run_git(["init"])
        if init.returncode != 0:
            self.log(f"⚠ Git init failed: {init.stderr.strip()}")
            return False

        run_git(["remote", "add", "origin", GITHUB_REPO_URL + ".git"])
        run_git(["config", "core.sparseCheckout", "true"])

        sparse_file = os.path.join(dest_dir, ".git", "info", "sparse-checkout")
        with open(sparse_file, "w", encoding="utf-8") as f:
            f.write("src/rfsuite/\n")
            f.write(".vscode/scripts/\n")
            # Grab all soundpacks to avoid missing locale audio during master installs
            f.write("bin/sound-generator/soundpack/\n")

        fetch = run_git(["fetch", "--depth", "1", "--progress", "origin", "master"], timeout=180)
        if fetch.returncode != 0:
            self.log(f"⚠ Git fetch failed: {fetch.stderr.strip()}")
            return False

        checkout = run_git(["checkout", "FETCH_HEAD"])
        if checkout.returncode != 0:
            self.log(f"⚠ Git checkout failed: {checkout.stderr.strip()}")
            return False

        self.log("✓ Sparse checkout completed")
        return True

    def copy_sound_pack(self, repo_dir, dest_dir, locale):
        """Copy sound pack for selected locale into destination tree."""
        locale = locale or DEFAULT_LOCALE
        src = os.path.join(repo_dir, "bin", "sound-generator", "soundpack", locale)
        self.log(f"  Audio source: {src}")
        if not os.path.isdir(src):
            if locale != DEFAULT_LOCALE:
                self.log(f"⚠ Sound pack for '{locale}' not found; using {DEFAULT_LOCALE}")
            locale = DEFAULT_LOCALE
            src = os.path.join(repo_dir, "bin", "sound-generator", "soundpack", locale)
            self.log(f"  Audio source fallback: {src}")
        if not os.path.isdir(src):
            self.log("⚠ Sound pack not found; skipping audio copy")
            return False

        dest = os.path.join(dest_dir, "audio", locale)
        try:
            if os.path.isdir(dest):
                self.log(f"  Removing existing audio pack: {dest}")
                shutil.rmtree(dest)
            os.makedirs(dest, exist_ok=True)
            self.log(f"  Copying audio pack to: {dest}")
            total_files = self.count_files(src)
            copied = 0
            for root, dirs, files in os.walk(src):
                rel_path = os.path.relpath(root, src)
                dst_dir = os.path.join(dest, rel_path) if rel_path != '.' else dest
                os.makedirs(dst_dir, exist_ok=True)
                for file in files:
                    src_file = os.path.join(root, file)
                    dst_file = os.path.join(dst_dir, file)
                    shutil.copy2(src_file, dst_file)
                    copied += 1
                    self.log(f"  [AUDIO {copied}/{total_files}] {os.path.relpath(src_file, src)}")
                    time.sleep(COPY_SETTLE_SECONDS)
            self.log(f"✓ Audio pack copied: {locale}")
            return True
        except Exception as e:
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
        
        self.is_updating = True
        self.update_button.config(state=tk.DISABLED)
        self.cancel_button.config(state=tk.NORMAL)
        self.progress.start()
        
        self.update_thread = threading.Thread(target=self.update_process, daemon=True)
        self.update_thread.start()
    
    def cancel_update(self):
        """Cancel the update process."""
        self.is_updating = False
        self.log("Update cancelled by user")
        self.set_status("Update cancelled")
        self.progress.stop()
        self.update_button.config(state=tk.NORMAL)
        self.cancel_button.config(state=tk.DISABLED)
    
    def update_process(self):
        """Main update process (runs in background thread)."""
        try:
            # Step 1: Check if radio is already mounted (storage mode)
            self.set_status("Looking for radio...")
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
            
            if not self.is_updating:
                return
            
            # Step 2: If not mounted, try to connect via HID and switch mode
            if not radio_already_mounted:
                self.set_status("Connecting to radio...")
                self.log("Radio not in storage mode, attempting to connect via USB HID...")
                
                try:
                    self.radio.connect()
                    self.log("✓ Radio connected via USB HID")
                except Exception as e:
                    self.log(f"✗ Failed to connect to radio: {e}")
                    self.log("Make sure the radio is connected via USB")
                    self.log("The radio should be either:")
                    self.log("  - In debug mode (will be switched automatically)")
                    self.log("  - In storage mode (mounted as a drive)")
                    raise
                
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
                    self.log("✗ Radio drive not found")
                    raise RuntimeError("Could not find radio scripts directory")
                
                self.log(f"✓ Found scripts directory: {scripts_dir}")
            else:
                # Radio was already mounted, scripts_dir is already set
                self.log("Skipping mount wait (radio already mounted)")
            
            if not self.is_updating:
                return
            
            # Step 5: Download suite from GitHub (or git sparse checkout for master)
            self.set_status("Preparing download...")

            version_type = self.selected_version.get()
            version_name = "master" if version_type == VERSION_MASTER else ""
            version_suffix = self.derive_version_suffix(version_type, version_name)
            locale = self.selected_locale.get() or DEFAULT_LOCALE
            self.log(f"Selected version: {version_name or version_type}")
            self.log(f"Selected locale: {locale}")
            self.log(f"Version suffix for main.lua: {version_suffix}")
            is_asset = False
            
            temp_dir = tempfile.mkdtemp(prefix="rfsuite-update-")
            # Sanitize version name for filename (replace / with -)
            safe_version_name = version_name.replace('/', '-').replace('\\', '-')
            zip_path = os.path.join(temp_dir, f"{safe_version_name}.zip")

            # For master, prefer sparse checkout to avoid full repo download
            repo_dir = None
            if version_type == VERSION_MASTER:
                self.set_status("Fetching master via git...")
                self.set_progress_mode('indeterminate')
                self.log("Git sparse checkout: src/rfsuite/, .vscode/scripts/, bin/sound-generator/soundpack/")
                repo_dir = os.path.join(temp_dir, "repo")
                if not self.sparse_checkout_master(repo_dir, locale):
                    repo_dir = None
                else:
                    self.log("✓ Using sparse checkout; skipping ZIP download")

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
                    req = Request(download_url, headers={'User-Agent': 'Mozilla/5.0'})
                    attempt = 0
                    while True:
                        attempt += 1
                        try:
                            self.log(f"  Download attempt {attempt}/{DOWNLOAD_RETRIES} (timeout {DOWNLOAD_TIMEOUT}s)")
                            with self.urlopen_insecure(req, timeout=DOWNLOAD_TIMEOUT) as response:
                                total_size = int(response.headers.get('content-length', 0))
                                size_known = total_size > 0
                                downloaded = 0

                                if size_known:
                                    self.set_progress_mode('determinate', maximum=total_size)
                                else:
                                    total_size = 50 * 1024 * 1024  # 50MB estimate
                                    self.set_progress_mode('determinate', maximum=total_size)
                                    self.log("  Download size unknown (no content-length); estimating 50MB")

                                last_log_percent = -1

                                with open(zip_path, 'wb') as f:
                                    while True:
                                        if not self.is_updating:
                                            return

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

                            break
                        except (URLError, HTTPError) as e:
                            if attempt >= DOWNLOAD_RETRIES:
                                raise
                            self.log(f"  Download failed: {e}. Retrying in {DOWNLOAD_RETRY_DELAY}s...")
                            time.sleep(DOWNLOAD_RETRY_DELAY)
                    self.log(f"✓ Downloaded {downloaded} bytes")
                except (URLError, HTTPError) as e:
                    self.log(f"✗ Download failed: {e}")
                    raise
            
            if not self.is_updating:
                return
            
            # Step 6: Extract archive (if we downloaded a zip)
            extract_dir = None
            if repo_dir is None:
                self.set_status("Extracting archive...")
                self.log("Extracting downloaded archive...")

                extract_dir = os.path.join(temp_dir, "extracted")

                try:
                    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                        zip_ref.extractall(extract_dir)
                    self.log("✓ Archive extracted")
                except Exception as e:
                    self.log(f"✗ Extraction failed: {e}")
                    raise
            
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
            
            # Step 8: Copy files to radio
            dest_dir = os.path.join(scripts_dir, TARGET_NAME)
            self.set_status("Copying files to radio...")
            self.log("Copying new files to radio...")
            
            # Remove old installation
            if os.path.isdir(dest_dir):
                self.log("  Removing old installation...")
                if not self.remove_tree_with_progress(dest_dir):
                    self.log("⚠ Removal cancelled")
                    return
            
            if not self.is_updating:
                return
            
            # Copy new files
            self.log("  Copying new files...")
            if not self.copy_tree_with_progress(src_dir, dest_dir):
                self.log("⚠ Copy cancelled")
                return
            
            self.log(f"✓ Files copied to radio successfully")

            self.set_status("Finalizing installation...")

            # Ensure audio pack matches selected locale for master/zip builds
            if not is_asset:
                self.log("Updating audio pack...")
                self.copy_sound_pack(repo_dir, dest_dir, locale)

            # Update main.lua version suffix only for master (release/snapshot assets already stamped)
            main_lua_path = os.path.join(dest_dir, "main.lua")
            if version_type == VERSION_MASTER:
                if os.path.isfile(main_lua_path):
                    self.update_main_lua_version(main_lua_path, version_suffix)
                else:
                    self.log(f"⚠ main.lua not found at {main_lua_path} for version update")
            
            if not self.is_updating:
                return
            
            # Step 9: Compile i18n translations (skip for prebuilt assets)
            if not is_asset:
                self.log("Preparing translation compiler (this can take a moment)...")
                self.set_status("Compiling translations...")
                self.log("Compiling i18n translations...")
                self.set_progress_mode('indeterminate')
                
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
                    
                    resolver_script = os.path.join(repo_dir, ".vscode", "scripts", "resolve_i18n_tags.py")
                    
                    if i18n_json and os.path.isfile(resolver_script):
                        self.log(f"  Using i18n JSON: {os.path.basename(i18n_json)}")
                        self.log(f"  Running resolver script...")
                        
                        result = subprocess.run(
                            [sys.executable, resolver_script, "--json", i18n_json, "--root", dest_dir],
                            capture_output=True,
                            text=True,
                            timeout=60
                        )
                        
                        if result.returncode == 0:
                            self.log("✓ i18n translations compiled successfully")
                            if result.stdout:
                                for line in result.stdout.strip().split('\n'):
                                    if line.strip():
                                        self.log(f"  {line}")
                        else:
                            self.log(f"⚠ i18n compilation failed (exit code {result.returncode})")
                            if result.stderr:
                                for line in result.stderr.strip().split('\n')[:5]:  # Show first 5 error lines
                                    if line.strip():
                                        self.log(f"  {line}")
                    else:
                        self.log("⚠ i18n files not found, skipping translation compilation")
                        if not os.path.isfile(i18n_json):
                            self.log(f"  Missing: {i18n_json}")
                        if not os.path.isfile(resolver_script):
                            self.log(f"  Missing: {resolver_script}")
                except subprocess.TimeoutExpired:
                    self.log("⚠ i18n compilation timed out")
                except Exception as e:
                    self.log(f"⚠ i18n compilation error: {e}")
            
            if not self.is_updating:
                return
            
            # Step 11: Cleanup
            self.log("Final cleanup...")
            self.set_status("Cleaning up...")
            self.log("Cleaning up temporary files...")
            self.set_progress_mode('indeterminate')
            try:
                shutil.rmtree(temp_dir)
            except Exception:
                pass
            
            # Success!
            self.set_status("Update completed successfully!")
            self.progress.stop()
            self.progress_label.config(text="")
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
            self.progress.stop()
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
    
    if hid is None:
        missing.append("hidapi (install with: pip install hidapi)")
    
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
        root.mainloop()
    except Exception:
        error_log = Path(__file__).resolve().parent / "updater_error.log"
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
