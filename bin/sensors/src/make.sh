#!/bin/bash
set -e
cd "$(dirname "$0")"

echo "[1/5] Checking for pyinstaller..."
if ! python3 -m PyInstaller --version > /dev/null 2>&1; then
    echo "PyInstaller not found. Run: pip install -r requirements.txt"
    exit 1
fi

echo "[2/5] Converting icon..."
sips -s format icns sensors.ico --out sensors.icns > /dev/null

echo "[3/5] Compiling sensors.py to standalone binary..."
python3 -m PyInstaller --onefile sensors.py --name sensors --windowed --icon=sensors.icns \
    --hidden-import tkinter \
    --hidden-import tkinter.ttk \
    --collect-all tkinter

echo "[4/5] Moving binary into parent folder..."
if [ -f ../sensors ]; then
    rm ../sensors
fi
mv dist/sensors ../sensors
chmod +x ../sensors

echo "[5/5] Cleaning up build tree..."
rm -rf build dist sensors.spec sensors.icns

echo "✅ Build complete. sensors is ready at: ../sensors"
