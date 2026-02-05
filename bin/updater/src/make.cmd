@echo off
setlocal
cd /d %~dp0

echo [1/5] Checking for pyinstaller...
pyinstaller --version >nul 2>&1
if errorlevel 1 (
    echo PyInstaller not found. Installing...
    pip install pyinstaller || goto :error
)

echo [2/5] Compiling update_radio_gui.py to standalone EXE...
python -m PyInstaller --onefile --noupx update_radio_gui.py --name update_radio_gui --windowed || goto :error

echo [3/5] Moving update_radio_gui.exe into parent folder...
if exist ..\update_radio_gui.exe (
    del ..\update_radio_gui.exe
)
move /Y dist\update_radio_gui.exe ..\update_radio_gui.exe >nul

echo [4/5] Cleaning up build tree...
rd /s /q build
rd /s /q dist
del /q update_radio_gui.spec

echo [5/5] ✅ Build complete. update_radio_gui.exe is ready at: ..\update_radio_gui.exe
goto :eof

:error
echo ❌ Build failed.
exit /b 1
