@echo off
setlocal

REM Official voices can be found here:  https://github.com/FrSkyRC/ETHOS-Feedback-Community/blob/1.6/tools/audio_packs.json

REM English - Default
python generate-googleapi.py --csv en.csv --voice en-US-Wavenet-D --base-dir en --variant default --engine google 

REM English - US
python generate-googleapi.py --csv en.csv --voice en-US-Wavenet-D --base-dir en --variant us --engine google 

REM English - US
python generate-googleapi.py --csv en.csv --voice en-GB-Neural2-A --base-dir en --variant gb --engine google 

REM French - Default
python generate-googleapi.py --csv fr.csv --voice en-GB-Neural2-A --base-dir en --variant default --engine google 

REM French - Femme
python generate-googleapi.py --csv fr.csv --voice en-GB-Neural2-A --base-dir en --variant femme --engine google 

REM French - Homme
python generate-googleapi.py --csv fr.csv --voice fr-FR-Standard-B --base-dir en --variant homme --engine google 

endlocal
