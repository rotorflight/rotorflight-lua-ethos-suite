@echo off

REM Accept an optional parameter for file extension
set "fileext=%~1"

if not "%fileext%"==".lua" (
    echo No file extension specified or unsupported parameter. Proceeding with default behavior.
)

set tgt=rfsuite
set srcfolder=%DEV_RFSUITE_GIT_SRC%
set dstfolder=%DEV_RADIO_SRC%

REM Extract the drive letter from dstfolder
for %%A in ("%dstfolder%") do set "driveLetter=%%~dA"

REM Preserve the logs folder by moving it temporarily
if exist "%dstfolder%\%tgt%\logs\" (
    mkdir "%dstfolder%\logs_temp"
    xcopy "%dstfolder%\%tgt%\logs\*" "%dstfolder%\logs_temp" /h /i /c /k /e /r /y
)

REM If .lua parameter is set, handle .lua files specifically
if "%fileext%"==".lua" (
    echo Removing all .lua files from target...
    for /r "%dstfolder%\%tgt%" %%F in (*.lua) do del "%%F"
    
    echo Syncing only .lua files to target...
    mkdir "%dstfolder%\%tgt%"
    xcopy "%srcfolder%\scripts\%tgt%\*.lua" "%dstfolder%\%tgt%" /h /i /c /k /e /r /y
) else (
    REM Remove the entire destination folder
    RMDIR "%dstfolder%\%tgt%" /S /Q

    REM Recreate the destination folder
    mkdir "%dstfolder%\%tgt%"
    
    REM Restore the logs folder
    if exist "%dstfolder%\logs_temp\" (
        mkdir "%dstfolder%\%tgt%\logs"
        xcopy "%dstfolder%\logs_temp\*" "%dstfolder%\%tgt%\logs" /h /i /c /k /e /r /y
        RMDIR "%dstfolder%\logs_temp" /S /Q
    )
    
    REM Copy all files to the destination folder
    xcopy "%srcfolder%\scripts\%tgt%" "%dstfolder%\%tgt%" /h /i /c /k /e /r /y
)

REM Restore logs if not handled already
if exist "%dstfolder%\logs_temp\" (
    mkdir "%dstfolder%\%tgt%\logs"
    xcopy "%dstfolder%\logs_temp\*" "%dstfolder%\%tgt%\logs" /h /i /c /k /e /r /y
    RMDIR "%dstfolder%\logs_temp" /S /Q
)

REM Dismount the volume as the last step
fsutil volume dismount %driveLetter%

echo Script execution completed.
