@echo off
setlocal
cd /d %~dp0

echo [1/5] Checking for pyinstaller...
pyinstaller --version >nul 2>&1
if errorlevel 1 (
    echo PyInstaller not found. Installing...
    pip install pyinstaller || goto :error
)

echo [2/5] Compiling update_radio_gui.py to standalone folder...
python -m PyInstaller --onedir --noupx update_radio_gui.py --name update_radio_gui --windowed || goto :error

echo [3/5] Zipping release to update_radio_gui.zip...
if exist ..\update_radio_gui.zip (
    del ..\update_radio_gui.zip
)
set "zip_ok=0"
for /l %%i in (1,1,6) do (
    powershell -NoProfile -Command "Compress-Archive -Path dist\\update_radio_gui\\* -DestinationPath ..\\update_radio_gui.zip -Force" && (
        set "zip_ok=1"
        goto :zip_done
    )
    echo   Zip attempt %%i failed. Retrying...
    timeout /t 2 >nul
)
:zip_done
if not "%zip_ok%"=="1" goto :error

echo [4/5] Cleaning up build tree...
rd /s /q build
rd /s /q dist
del /q update_radio_gui.spec

echo [5/5] Build complete. update_radio_gui.zip is ready at: ..\update_radio_gui.zip
goto :eof

:error
echo ❌ Build failed.
exit /b 1
