@echo off
REM Rotorflight Lua Ethos Suite Radio Updater Launcher
REM This batch file makes it easy to run the updater on Windows

echo ========================================
echo Rotorflight Radio Updater
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7 or higher from python.org
    echo.
    pause
    exit /b 1
)

echo Python found!
echo.

REM Check if dependencies are installed
echo Checking dependencies...
python -c "import hid" >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies...
    python -m pip install -r requirements_updater.txt
    if errorlevel 1 (
        echo.
        echo ERROR: Failed to install dependencies
        echo Please run: pip install -r requirements_updater.txt
        echo.
        pause
        exit /b 1
    )
) else (
    echo Dependencies OK!
)

echo.
echo Starting updater...
echo.

REM Run the updater
pythonw update_radio_gui.py

if errorlevel 1 (
    echo.
    echo ERROR: Failed to start updater
    pause
    exit /b 1
)

exit /b 0
