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
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

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
        
        self.setup_ui()
    
    def setup_ui(self):
        """Setup the user interface."""
        # Title
        title_frame = ttk.Frame(self.root, padding="10")
        title_frame.pack(fill=tk.X)
        
        title_label = ttk.Label(
            title_frame,
            text="Rotorflight Lua Ethos Suite Updater",
            font=("Arial", 16, "bold")
        )
        title_label.pack()
        
        subtitle_label = ttk.Label(
            title_frame,
            text="Update your Ethos radio with the latest suite from GitHub",
            font=("Arial", 10)
        )
        subtitle_label.pack()
        
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
    
    def log(self, message):
        """Add a message to the log."""
        timestamp = time.strftime("%H:%M:%S")
        self.log_text.insert(tk.END, f"[{timestamp}] {message}\n")
        self.log_text.see(tk.END)
        self.root.update_idletasks()
    
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
    
    def get_download_url_and_name(self):
        """Get the download URL and version name based on selected version."""
        import json
        
        version_type = self.selected_version.get()
        
        if version_type == VERSION_MASTER:
            # Master branch
            url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
            name = "master"
            return url, name
        
        elif version_type == VERSION_SNAPSHOT:
            # Snapshot branch - try to get pre-release from GitHub API
            try:
                self.log("Fetching latest pre-release information...")
                req = Request(f"{GITHUB_API_URL}/releases", headers={'User-Agent': 'Mozilla/5.0'})
                with urlopen(req, timeout=10) as response:
                    data = json.loads(response.read().decode())
                    # Find first pre-release
                    for release in data:
                        if release.get('prerelease', False):
                            tag_name = release.get('tag_name', '')
                            if tag_name:
                                url = f"{GITHUB_REPO_URL}/archive/refs/tags/{tag_name}.zip"
                                self.log(f"✓ Found latest pre-release: {tag_name}")
                                return url, tag_name
                    # No pre-release found, fall back to master
                    self.log("⚠ No pre-release found, using master branch")
                    url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
                    name = "master (no snapshot)"
                    return url, name
            except Exception as e:
                self.log(f"⚠ Failed to fetch pre-release info: {e}")
                self.log("  Falling back to master branch")
                url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
                name = "master (fallback)"
                return url, name
        
        elif version_type == VERSION_RELEASE:
            # Latest release
            try:
                self.log("Fetching latest release information...")
                req = Request(f"{GITHUB_API_URL}/releases/latest", headers={'User-Agent': 'Mozilla/5.0'})
                with urlopen(req, timeout=10) as response:
                    data = json.loads(response.read().decode())
                    tag_name = data.get('tag_name', '')
                    if tag_name:
                        url = f"{GITHUB_REPO_URL}/archive/refs/tags/{tag_name}.zip"
                        self.log(f"✓ Found latest release: {tag_name}")
                        return url, tag_name
                    else:
                        raise RuntimeError("No tag_name in release data")
            except Exception as e:
                self.log(f"⚠ Failed to fetch release info: {e}")
                self.log("  Falling back to master branch")
                url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
                name = "master (fallback)"
                return url, name
        
        # Default fallback
        url = f"{GITHUB_REPO_URL}/archive/refs/heads/master.zip"
        name = "master"
        return url, name
    
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
            
            # Step 5: Download suite from GitHub
            self.set_status("Downloading suite from GitHub...")
            
            # Get download URL based on selected version
            download_url, version_name = self.get_download_url_and_name()
            self.log(f"Selected version: {version_name}")
            self.log(f"Downloading from: {download_url}")
            
            temp_dir = tempfile.mkdtemp(prefix="rfsuite-update-")
            # Sanitize version name for filename (replace / with -)
            safe_version_name = version_name.replace('/', '-').replace('\\', '-')
            zip_path = os.path.join(temp_dir, f"{safe_version_name}.zip")
            
            try:
                req = Request(download_url, headers={'User-Agent': 'Mozilla/5.0'})
                with urlopen(req, timeout=30) as response:
                    total_size = int(response.headers.get('content-length', 0))
                    downloaded = 0
                    
                    with open(zip_path, 'wb') as f:
                        while True:
                            if not self.is_updating:
                                return
                            
                            chunk = response.read(8192)
                            if not chunk:
                                break
                            
                            f.write(chunk)
                            downloaded += len(chunk)
                            
                            if total_size > 0:
                                percent = (downloaded / total_size) * 100
                                self.log(f"  Downloaded: {downloaded}/{total_size} bytes ({percent:.1f}%)")
                
                self.log(f"✓ Downloaded {downloaded} bytes")
            except (URLError, HTTPError) as e:
                self.log(f"✗ Download failed: {e}")
                raise
            
            if not self.is_updating:
                return
            
            # Step 6: Extract archive
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
            
            # GitHub creates a folder like "rotorflight-lua-ethos-suite-master"
            extracted_items = os.listdir(extract_dir)
            if not extracted_items:
                raise RuntimeError("Extracted archive is empty")
            
            repo_dir = os.path.join(extract_dir, extracted_items[0])
            
            # Try different possible locations for the source
            possible_paths = [
                os.path.join(repo_dir, "src", TARGET_NAME),      # Standard: src/rfsuite
                os.path.join(repo_dir, "scripts", TARGET_NAME),  # Alternative: scripts/rfsuite
                os.path.join(repo_dir, TARGET_NAME),             # Direct: rfsuite
            ]
            
            src_dir = None
            for path in possible_paths:
                if os.path.isdir(path):
                    src_dir = path
                    self.log(f"✓ Found source: {os.path.relpath(path, extract_dir)}")
                    break
            
            if not src_dir:
                self.log(f"✗ Source directory not found in any of these locations:")
                for path in possible_paths:
                    self.log(f"  - {os.path.relpath(path, extract_dir)}")
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
            
            if not self.is_updating:
                return
            
            # Step 9: Compile i18n translations
            self.set_status("Compiling translations...")
            self.log("Compiling i18n translations...")
            self.set_progress_mode('indeterminate')
            
            try:
                # Find i18n JSON file in the extracted repo (try multiple locations)
                i18n_json = None
                for base_path in [
                    os.path.join(repo_dir, "src", TARGET_NAME, "i18n", "en.json"),
                    os.path.join(repo_dir, "scripts", TARGET_NAME, "i18n", "en.json"),
                    os.path.join(repo_dir, TARGET_NAME, "i18n", "en.json"),
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
    if not check_dependencies():
        sys.exit(1)
    
    root = tk.Tk()
    app = UpdaterGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
