#!/bin/bash
# Rotorflight Lua Ethos Suite Radio Updater Launcher
# This script makes it easy to run the updater on Linux/macOS

echo "========================================"
echo "Rotorflight Radio Updater"
echo "========================================"
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    echo "Please install Python 3.7 or higher"
    echo ""
    read -p "Press Enter to exit..."
    exit 1
fi

echo "Python found: $(python3 --version)"
echo ""

# Check if dependencies are installed
echo "Checking dependencies..."
if ! python3 -c "import hid" &> /dev/null; then
    echo "Installing dependencies..."
    python3 -m pip install -r requirements_updater.txt
    
    if [ $? -ne 0 ]; then
        echo ""
        echo "ERROR: Failed to install dependencies"
        echo "Please run: pip3 install -r requirements_updater.txt"
        echo ""
        read -p "Press Enter to exit..."
        exit 1
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
