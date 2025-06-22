@echo off
setlocal

REM Voices can be found here:
REM https://cloud.google.com/text-to-speech/docs/list-voices-and-types

REM Custom user voice
python generate-googleapi.py --only-missing --csv en.csv --voice en-AU-Standard-A --base-dir user --variant default --engine google 



endlocal
