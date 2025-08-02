# Rotorflight RFSUITE Sensor Updater

This folder contains the Python GUI script and build tools for generating a standalone Windows executable for updating simulated sensor values used in Rotorflight RFSUITE testing.

---

## ✅ Requirements

- Python 3.7+
- `pip`
- Internet access (only for first-time `pyinstaller` install)

---

## 📁 File Layout

```
src\
  sensors.py       # Main GUI script
  make.cmd        # Compile to sensors.exe
  README.md        # This file
..
  sensors.exe      # Compiled binary output (written one level up)
```

---

## 🌍 Environment Variables

Before running the app or building, set the following environment variables:

### `FRSKY_RFSUITE_GIT_SRC`
- Path to the root of the Rotorflight RFSUITE source repo.
- Must contain:
  - `scripts\rfsuite\tasks\telemetry\telemetry.lua`
  - `bin\i18n\json\telemetry\en.json`

### `FRSKY_SIM_SRC`
- One or more comma-separated paths to the simulated sensor output directories.
- Each must allow writing Lua scripts to:
  - `rfsuite\sim\sensors\<sensor>.lua`

**Example:**
```bat
set FRSKY_RFSUITE_GIT_SRC=C:\GitHub\rotorflight-lua-ethos-suite
set FRSKY_SIM_SRC=C:\GitHub\rotorflight-lua-ethos-suite\output
```

---

## 🛠️ Build Instructions

Run the batch file to compile the GUI:
```bat
build.bat
```
This will:
- Compile `sensors.py` to `sensors.exe`
- Output the `.exe` to `..\sensors.exe`
- Clean up all build artifacts

---

## 🖥️ Running the GUI

Double-click `sensors.exe` after building,
or from the CLI:
```bat
sensors.exe
```

---

## 🔊 Features
- List all available sensors (except `rssi`)
- Set fixed values or random ranges for each
- Live inline status update + 5 second timeout
- Audio beep on successful update

---

## 📄 License
This project is part of Rotorflight RFSUITE. For licensing details, refer to the upstream repository.
