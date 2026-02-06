# Rotorflight Radio Updater

Windows updater for the Rotorflight Lua Ethos Suite.

![Rotorflight Radio Updater](https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/bin/updater/README.png)

## Download

Windows executable:

[RFSuite Updater Download](https://raw.githubusercontent.com/rotorflight/rotorflight-lua-ethos-suite/master/bin/updater/update_radio_gui.exe)

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
