@echo off
setlocal
cd /d %~dp0

echo [1/4] Checking for pyinstaller...
pyinstaller --version >nul 2>&1
if errorlevel 1 (
    echo PyInstaller not found. Installing...
    pip install pyinstaller || goto :error
)

echo [2/4] Compiling menu_editor.py to standalone EXE...
python -m PyInstaller --onefile --noupx menu_editor.py --name menu_editor --windowed || goto :error

echo [3/4] Moving menu_editor.exe into parent folder...
if exist ..\menu_editor.exe (
    del ..\menu_editor.exe
)
move /Y dist\menu_editor.exe ..\menu_editor.exe >nul

echo [4/4] Cleaning up build tree...
rd /s /q build
rd /s /q dist
del /q menu_editor.spec

echo Build complete. menu_editor.exe is ready at: ..\menu_editor.exe

goto :eof

:error
echo Build failed.
exit /b 1
