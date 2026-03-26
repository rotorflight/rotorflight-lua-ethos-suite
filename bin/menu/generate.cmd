@echo off
setlocal

set "SCRIPT_DIR=%~dp0"

where py >nul 2>&1
if %errorlevel%==0 (
    py -3 "%SCRIPT_DIR%generate.py" %*
) else (
    python "%SCRIPT_DIR%generate.py" %*
)

endlocal & exit /b %errorlevel%
