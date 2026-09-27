@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

where py >nul 2>&1
if %errorlevel%==0 (
    set "PYTHON=py -3"
    goto :run
)

where python >nul 2>&1
if %errorlevel%==0 (
    set "PYTHON=python"
    goto :run
)

if exist "C:\msys64\ucrt64\bin\python.exe" (
    set "PYTHON=C:\msys64\ucrt64\bin\python.exe"
    goto :run
)

echo [ERROR] Python not found in PATH or at C:\msys64\ucrt64\bin\python.exe. >&2
exit /b 1

:run
%PYTHON% "%SCRIPT_DIR%generate_menu_docs.py" %*
exit /b %errorlevel%
