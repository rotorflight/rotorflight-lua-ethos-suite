@echo off
setlocal

REM Update missing translations
python update-missing-translations.py json/

REM Voices can be found here:
REM https://cloud.google.com/text-to-speech/docs/list-voices-and-types

REM Custom user voice
python generate-googleapi.py --only-missing --json json/en.json --voice en-AU-Standard-A --base-dir user --variant default --engine google 



endlocal
