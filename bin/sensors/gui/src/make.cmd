@echo off
setlocal
cd /d %~dp0

echo [1/5] Checking for pyinstaller...
pyinstaller --version >nul 2>&1
if errorlevel 1 (
    echo PyInstaller not found. Installing...
    pip install pyinstaller || goto :error
)

echo [2/5] Compiling sensors.py to standalone EXE...
python -m PyInstaller --onefile sensors.py --name sensors --windowed --icon=sensors.ico || goto :error

echo [3/5] Moving sensors.exe into parent folder...
if exist ..\sensors.exe (
    del ..\sensors.exe
)
move /Y dist\sensors.exe ..\sensors.exe >nul

echo [4/5] Cleaning up build tree...
rd /s /q build
rd /s /q dist
del /q sensors.spec

echo [5/5] ✅ Build complete. sensors.exe is ready at: ..\sensors.exe
goto :eof

:error
echo ❌ Build failed.
exit /b 1
