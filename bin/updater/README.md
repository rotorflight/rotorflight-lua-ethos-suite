# Rotorflight Radio Updater

Windows updater for the Rotorflight Lua Ethos Suite.

![Rotorflight Radio Updater](https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/bin/updater/README.png)

## Download

Latest release assets (Windows/macOS/Linux) are published on the GitHub Releases page:

[RFSuite Updater Releases](https://github.com/rotorflight/rotorflight-lua-ethos-suite/releases/latest)

Asset names:
- Windows: `rfsuite-updater-<version>-windows.zip`
- macOS: `rfsuite-updater-<version>-macos.zip`
- Linux: `updater-ubuntu-latest` (workflow artifacts; not yet attached to releases)

## Developer Notes

The updater checks for updates by loading:

`bin/updater/src/release.json`

You should update this file if releasing a new version.

Compilation requirements:

1. Windows build host (PyInstaller target).
2. Python 3.x on PATH.
3. PyInstaller installed: `pip install pyinstaller`
4. From `bin/updater/src`, run: `make.cmd`
5. Output EXE: `bin/updater/update_radio_gui.exe`

Optional build inputs:

- `bin/updater/src/icon.ico` (embedded icon used by `make.cmd`)

## macOS / Linux Notes

- The updater uses `tkinter` for the GUI. Ensure your Python install includes Tk support.
  - macOS: the python.org installer typically includes Tk.
  - Linux: install your distro's `python3-tk` package.
- HID support is optional. If `hid`/`hidapi` is missing, the updater can still work
  when the radio is already mounted in storage mode.
- For development runs on macOS/Linux, use:
  - `bin/updater/src/run_updater.sh`
- macOS icon: generate `icon.icns` from the Windows `.ico` with:
  - `python3 bin/updater/src/build_icon_icns.py`
