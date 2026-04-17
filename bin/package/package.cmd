@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_ROOT=%%~fI"

if /I "%~1"=="--help" goto :help
if /I "%~1"=="-h" goto :help
if /I "%~1"=="/?" goto :help

set "LANGUAGE=%~1"
if "%LANGUAGE%"=="" set "LANGUAGE=en"

set "ARTIFACT_VERSION=%~2"
if "%ARTIFACT_VERSION%"=="" set "ARTIFACT_VERSION=local-test"

if not "%~1"=="" shift
if not "%~1"=="" shift

set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"

where py >nul 2>&1
if %errorlevel%==0 (
    set "PYTHON=py -3"
) else (
    set "PYTHON=python"
)

echo [package] language=%LANGUAGE%
echo [package] artifact-version=%ARTIFACT_VERSION%

%PYTHON% "%SCRIPT_DIR%build_package.py" ^
    --lang "%LANGUAGE%" ^
    --artifact-version "%ARTIFACT_VERSION%" ^
    --output-dir "%CD%" ^
    %*
exit /b %errorlevel%

:help
echo Usage: package.cmd [lang] [artifact-version] [extra build_package.py args...]
echo.
echo Defaults:
echo   lang             en
echo   artifact-version local-test
echo   build-root       temporary scratch directory
echo   output-dir       current directory
echo.
echo Examples:
echo   package.cmd
echo   package.cmd en 2.3.0
echo   package.cmd en 2.3.0 --keep-build-root --build-root C:\temp\rfsuite-package
echo   package.cmd fr 2.3.0-20260208 --release-notes-file C:\temp\Notes.md
exit /b 0
