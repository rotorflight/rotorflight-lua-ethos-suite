@echo off
setlocal

if /I "%~1"=="--help" goto :help
if /I "%~1"=="-h" goto :help

if "%~1"=="" (
    echo [i18n] Generating all locales...
    python update-missing-translations.py || goto :error
    python update-max-lengths.py || goto :error
    python build-single-json.py || goto :error
) else (
    echo [i18n] Generating selected locales: %*
    python update-missing-translations.py --only %* || goto :error
    python update-max-lengths.py --only %* || goto :error
    python build-single-json.py --only %* || goto :error
)

echo [i18n] Done.
exit /b 0

:help
echo Usage: generate.cmd [locale ...]
echo.
echo Examples:
echo   generate.cmd
echo   generate.cmd nl
echo   generate.cmd nl de
exit /b 0

:error
echo [i18n] Failed.
exit /b 1
