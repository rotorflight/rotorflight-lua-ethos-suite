@echo off
setlocal
cd /d %~dp0

echo [1/4] Checking for pyinstaller...
pyinstaller --version >nul 2>&1
if errorlevel 1 (
    echo PyInstaller not found. Installing...
    pip install pyinstaller || goto :error
)

echo [2/4] Compiling translation_editor.py to standalone EXE...
python -m PyInstaller --onefile --noupx translation_editor.py --name translation_editor --windowed || goto :error

echo [3/4] Moving translation_editor.exe into parent folder...
if exist ..\translation_editor.exe (
    del ..\translation_editor.exe
)
move /Y dist\translation_editor.exe ..\translation_editor.exe >nul

echo [4/4] Cleaning up build tree...
rd /s /q build
rd /s /q dist
del /q translation_editor.spec

echo ✅ Build complete. translation_editor.exe is ready at: ..\translation_editor.exe

goto :eof

:error
echo ❌ Build failed.
exit /b 1
