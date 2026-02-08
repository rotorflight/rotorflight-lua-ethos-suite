@echo off
setlocal

REM Update missing translations
python update-missing-translations.py json/

REM Official voices can be found here:  https://github.com/FrSkyRC/ETHOS-Feedback-Community/blob/1.6/tools/audio_packs.json

REM English - Default
python generate-googleapi.py --only-missing --json json/en.json --voice en-US-Wavenet-F --base-dir en --variant default --engine google 

REM English - US
python generate-googleapi.py --only-missing --json json/en.json --voice en-US-Wavenet-F --base-dir en --variant us --engine google 

REM English - GB
python generate-googleapi.py --only-missing --json json/en.json --voice en-GB-Neural2-A --base-dir en --variant gb --engine google 

REM French - Default
python generate-googleapi.py --only-missing --json json/fr.json --voice fr-FR-Neural2-F --base-dir fr --variant default --engine google 

REM French - Femme
python generate-googleapi.py --only-missing --json json/fr.json --voice fr-FR-Neural2-F --base-dir fr --variant femme --engine google 

REM French - Homme
python generate-googleapi.py --only-missing --json json/fr.json --voice fr-FR-Standard-B --base-dir fr --variant homme --engine google 

REM Spanish - Default
python generate-googleapi.py --only-missing --json json/es.json --voice es-ES-Wavenet-C --base-dir es --variant default --engine google 

REM German - Default
python generate-googleapi.py --only-missing --json json/de.json --voice de-DE-Wavenet-E --base-dir de --variant default --engine google 

REM Dutch - Default
python generate-googleapi.py --only-missing --json json/nl.json --voice nl-NL-Standard-A --base-dir nl --variant default --engine google 

REM Italian - Default
python generate-googleapi.py --only-missing --json json/it.json --voice it-IT-Wavenet-B --base-dir it --variant default --engine google 

REM Portuguese (Brazil) - Default
python generate-googleapi.py --only-missing --json json/pt-br.json --voice pt-BR-Wavenet-A --base-dir pt-br --variant default --engine google 

REM Norwegian - Default
python generate-googleapi.py --only-missing --json json/no.json --voice nb-NO-Standard-E --base-dir no --variant default --engine google 

REM Czech - Default
python generate-googleapi.py --only-missing --json json/cs.json --voice cs-CZ-Wavenet-A --base-dir cs --variant default --engine google 

REM copy just english to the release folder
xcopy soundpack\en\ ..\..\src\rfsuite\audio\en\ /E /I /Y

endlocal
