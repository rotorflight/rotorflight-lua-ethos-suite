
# RF Suite Sensor Editor

A simple GUI tool for managing Lua script values used by RF Suite.

---

## 🚀 Usage Guide

### 📂 Set the Folder Path for Lua Files

The RF Suite Sensor Editor needs to know which folder contains the Lua files to edit. There are **three ways** to set this path:

---

### ✅ Option 1: Pass the Path via Command-Line Argument (Direct Launch)

When running the app, provide the folder path directly:

```bash
python main.py "C:\path\to\your\lua\files"
```

Example:
```bash
python main.py "C:\Program Files (x86)\FrSky\Ethos\X20S\scripts\rfsuite.simtelemetry"
```

---

### ✅ Option 2: Use Environment Variable (Persistent Option)

Set the environment variable `DEV_RFSUITE.SIM_PATH` to point to your Lua folder. This way, you don’t need to pass the folder every time.

#### On Windows (Temporary for Current Terminal)

```bash
set DEV_RFSUITE.SIM_PATH=C:\path\to\your\lua\files
python main.py
```

#### On Windows (Permanent - Recommended)

1. Open **Control Panel**.
2. Navigate to **System > Advanced system settings > Environment Variables**.
3. Add a new **User variable** called `DEV_RFSUITE.SIM_PATH`.
4. Set the value to your Lua folder path, e.g.:
```
C:\Program Files (x86)\FrSky\Ethos\X20S\scripts\rfsuite.simtelemetry
```

Once set, you can just run:

```bash
python main.py
```

---

### ✅ Option 3: Use Built-in Default Path (Automatic Fallback)

If no CLI argument and no environment variable is provided, the app defaults to:
```
C:\Program Files (x86)\FrSky\Ethos\X20S\scripts\rfsuite.simtelemetry
```

---

## ✅ Example Workflows

### Example 1 - Direct Run with Path
```bash
python main.py "C:\My\Custom\Lua\Folder"
```

### Example 2 - Using Environment Variable (for Current Session)
```bash
set DEV_RFSUITE.SIM_PATH=C:\My\Custom\Lua\Folder
python main.py
```

### Example 3 - Using Permanent Environment Variable (Set Once)
Once you set `DEV_RFSUITE.SIM_PATH`, just run:
```bash
python main.py
```

---

## 💡 Bonus - Easy `run_editor.bat` Example

For even more convenience, you can create a batch file called `run_editor.bat`:

**run_editor.bat**
```bat
@echo off
set DEV_RFSUITE.SIM_PATH=C:\My\Custom\Lua\Folder
python main.py
pause
```

Double-clicking `run_editor.bat` will launch the editor with the correct folder.

---

## 📦 Requirements

- Python 3.10+
- PyQt6 (Install with `pip install pyqt6`)
- Install other requirements using:
```bash
pip install -r requirements.txt
```

---

## 🏗️ Building an EXE (Optional)

To build a standalone EXE, run:
```bash
pip install pyinstaller
pyinstaller --noconsole --onefile main.py
```
This will create `dist\main.exe` which you can rename if desired.


