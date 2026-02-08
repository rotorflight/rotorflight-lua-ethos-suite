#!/bin/bash
# Rotorflight Lua Ethos Suite Radio Updater Launcher
# This script makes it easy to run the updater on Linux/macOS

echo "========================================"
echo "Rotorflight Radio Updater"
echo "========================================"
echo ""

die() {
    echo ""
    echo "ERROR: $1"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
}

warn() {
    echo "WARNING: $1"
}

check_import() {
    local module="$1"
    python3 -c "import ${module}" &> /dev/null
}

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    die "Python 3 is not installed. Please install Python 3.7 or higher."
fi

echo "Python found: $(python3 --version)"
echo ""

# Check if pip is installed
if ! python3 -m pip --version &> /dev/null; then
    die "pip is not available. Please install pip for Python 3."
fi

# Check GUI dependency
echo "Checking GUI dependencies..."
if ! check_import "tkinter"; then
    echo "tkinter is missing."
    echo "macOS: install a Python build with Tk support (python.org installer recommended),"
    echo "or ensure tcl/tk is installed and discoverable."
    echo "Linux: install your distro package for Tk (e.g. python3-tk)."
    die "tkinter is required to run the updater GUI."
fi

# Check HID dependency (optional)
echo "Checking HID dependencies..."
if ! check_import "hid" && ! check_import "hidapi"; then
    warn "hid/hidapi not found. USB HID mode switching will be unavailable."
    warn "You can still update if the radio is already mounted in storage mode."
    echo "Attempting to install dependencies..."
    python3 -m pip install -r requirements_updater.txt
    if [ $? -ne 0 ]; then
        warn "Failed to install dependencies automatically."
        echo "Please run: pip3 install -r requirements_updater.txt"
    fi
else
    echo "Dependencies OK!"
fi

echo ""
echo "Starting updater..."
echo ""

# Run the updater
python3 update_radio_gui.py

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Failed to start updater"
    read -p "Press Enter to exit..."
    exit 1
fi

exit 0
