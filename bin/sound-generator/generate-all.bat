@echo off
setlocal

REM Official voices can be found here:  https://github.com/FrSkyRC/ETHOS-Feedback-Community/blob/1.6/tools/audio_packs.json

REM English - Default
python generate-googleapi.py --csv en.csv --voice en-US-Wavenet-F --base-dir en --variant default --engine google 

REM English - US
python generate-googleapi.py --csv en.csv --voice en-US-Wavenet-F --base-dir en --variant us --engine google 

REM English - GB
python generate-googleapi.py --csv en.csv --voice en-GB-Neural2-A --base-dir en --variant gb --engine google 

REM French - Default
python generate-googleapi.py --csv fr.csv --voice fr-FR-Neural2-F --base-dir fr --variant default --engine google 

REM French - Femme
python generate-googleapi.py --csv fr.csv --voice fr-FR-Neural2-F --base-dir fr --variant femme --engine google 

REM French - Homme
python generate-googleapi.py --csv fr.csv --voice fr-FR-Standard-B --base-dir fr --variant homme --engine google 

REM Spanish - Default
python generate-googleapi.py --csv es.csv --voice es-ES-Wavenet-C --base-dir es --variant default --engine google 

REM German - Default
python generate-googleapi.py --csv de.csv --voice de-DE-Wavenet-E --base-dir de --variant default --engine google 

REM Dutch - Default
python generate-googleapi.py --csv nl.csv --voice nl-NL-Standard-A --base-dir nl --variant default --engine google 

REM Italian - Default
python generate-googleapi.py --csv it.csv --voice it-IT-Wavenet-B --base-dir it --variant default --engine google 

endlocal
