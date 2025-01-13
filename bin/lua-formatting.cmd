@echo off
setlocal enabledelayedexpansion

:: Check if the script is being run from a directory named 'bin'
for %%d in ("%cd%") do set current_folder=%%~nxd
if not "%current_folder%"=="bin" (
    echo Error: This script must be run from the 'bin' directory.
    exit /b 1
)

:: Check if .lua-format file exists in the current directory
if not exist ".lua-format" (
    echo Error: .lua-format file not found in the current directory.
    exit /b 1
)

:: Check if the first argument is provided
if "%~1"=="" (
    echo Error: No path specified.
    echo Usage: %~nx0 ^<file or directory^>
    exit /b 1
)

:: Check if the provided path is a valid file
if exist "%~1" (
    if not exist "%~1\" (
        echo Formatting file: %~1
        lua-format.exe -i "%~1"
        exit /b 0
    )
)

:: Check if the provided path is a valid directory
if not exist "%~1" (
    echo Error: '%~1' is not a valid file or directory.
    exit /b 1
)

:: If it's a directory, format all .lua files recursively
echo Formatting directory: %~1
for /r "%~1" %%f in (*.lua) do (
    echo Formatting: %%f
    lua-format.exe -i "%%f"
)

echo Formatting completed.
