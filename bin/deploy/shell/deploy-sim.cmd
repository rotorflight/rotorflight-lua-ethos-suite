@echo off
REM ------------------------------------------------------
REM   FILE COPY SCRIPT FOR MULTIPLE DESTINATION FOLDERS
REM ------------------------------------------------------
REM   This script copies files from a Git source folder to multiple destination folders.
REM   Destination folders are specified in a CSV list using the %FRSKY_SIM_SRC% environment variable.
REM   The script can optionally handle specific file extensions (e.g., .lua files).

REM ------------------------------------------------------
REM   SETUP INSTRUCTIONS (WINDOWS)
REM ------------------------------------------------------
REM 1. Set the environment variables in Windows Command Prompt (or add them to System Variables):
REM    Example:
REM    set FRSKY_RFSUITE_GIT_SRC=C:\Path\To\Your\Source
REM    set FRSKY_SIM_SRC="C:\Program Files (x86)\FrSky\Ethos\X20S\scripts","C:\Program Files (x86)\FrSky\Ethos\X14S\scripts","C:\Program Files (x86)\FrSky\Ethos\X18S\scripts"

REM 2. Run the script from the Command Prompt:
REM    Example (copy all files):
REM    your_script.bat

REM 3. Optional: To copy only .lua files, pass .lua as a parameter:
REM    Example:
REM    deploy-sim.cmd .lua

REM ------------------------------------------------------
REM SCRIPT BEGINS BELOW
REM ------------------------------------------------------


REM Accept an optional parameter for file extension
set "fileext=%~1"

if not defined fileext (
    echo No file extension specified. Copying all files.
) else (
    echo File extension specified: %fileext%
)

set "tgt=rfsuite"
set "srcfolder=%FRSKY_RFSUITE_GIT_SRC%"
set "destfolders=%FRSKY_SIM_SRC%"

REM Convert CSV list to array by replacing commas with spaces and handling quotes
for %%d in ("%destfolders:,=" "%") do (
    echo Processing destination folder: %%~d


    REM Handle the case where .lua is passed as a parameter
    if "%fileext%"==".lua" (
        echo Removing all .lua files from target in %%~d...
        for /r "%%~d\%tgt%" %%F in (*.lua) do del "%%F" >nul 2>&1

        echo Syncing only .lua files to target in %%~d...
        mkdir "%%~d\%tgt%" >nul 2>&1
        xcopy "%srcfolder%\scripts\%tgt%\*.lua" "%%~d\%tgt%" /h /i /c /k /e /r /y >nul 2>&1
    ) else (
        REM No specific file extension, remove and copy all files
        RMDIR "%%~d\%tgt%" /S /Q >nul 2>&1

        REM Recreate the destination folder
        mkdir "%%~d\%tgt%" >nul 2>&1

        REM Copy all files to the destination folder
        xcopy "%srcfolder%\scripts\%tgt%" "%%~d\%tgt%" /h /i /c /k /e /r /y >nul 2>&1
    )

    echo Copy completed for: %%~d
)

echo Script execution completed.
