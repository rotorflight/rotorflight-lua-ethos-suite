# Locale Add/Update Touch Points

This document highlights the touch points and workflow used to add or update locales (e.g., `pt-br`, `no`) in this repo.

## Quick Checklist
1. Add i18n source file under `bin/i18n/json/<locale>.json`.
2. Build/verify locale JSON into `src/rfsuite/i18n/<locale>.json`.
3. Add locale to workflow matrices so per-locale ZIPs are built.
4. Add locale to the updater GUI locale list (in the updater repo).
5. Add sound pack sources and generated audio (if applicable).
6. (Optional) Update demo links or docs that mention locales.

## Touch Points (By Area)
### 1) i18n Source Files (authoritative inputs)
Single-file locale sources (authoritative inputs):
- `bin/i18n/json/<locale>.json`

### 2) Locale JSON (generated output)
Build or update:
- `src/rfsuite/i18n/<locale>.json`

Built by (sync/copy):
- `bin/i18n/build-single-json.py --only <locale>`

### 3) CI/Workflows (per-locale builds)
Add/remove locales in the language matrix:
- `.github/workflows/pr.yml`
- `.github/workflows/push.yml`
- `.github/workflows/release.yml`
- `.github/workflows/snapshot.yml`

These workflows:
- Build merged JSON per locale.
- Resolve `@i18n(...)@` tags for each locale.
- Package per-locale ZIPs.
- Copy per-locale sound packs into the staged tree.

### 4) Updater GUI (locale selection + asset naming)
Update locale list in:
- `rotorflight-lua-ethos-suite-updater/src/update_radio_gui.py`

Specifically:
- `AVAILABLE_LOCALES = ["en", ...]`

The updater uses this to populate the locale dropdown and pick release assets named
`rotorflight-lua-ethos-suite-<version>-<locale>.zip`.

### 5) Sound Packs (optional but recommended)
If you support spoken audio:
- `bin/sound-generator/json/<locale>.json` (TTS strings)
- `bin/sound-generator/soundpack/<locale>/` (generated audio)
- `bin/sound-generator/generate-all.bat` (voice presets per locale)

Note:
- The release packaging steps copy `bin/sound-generator/soundpack/<locale>` into the locale build if present.

### 6) Demo/Docs (optional)
If you want demo links for the new locale:
- `demo/readme.md`

## Suggested Workflow
1. Add/update translation JSON under `bin/i18n/json/<locale>.json`.
2. Run `bin/i18n/update-max-lengths.py` to refresh per-key `max_length` in `en.json`.
3. Run `bin/i18n/build-single-json.py --only <locale>` to rebuild `src/rfsuite/i18n/<locale>.json`.
3. Add `<locale>` to all workflow matrices.
4. Add `<locale>` to `AVAILABLE_LOCALES` in the updater GUI.
5. Add or generate sound packs (if used).
6. (Optional) Update demo/docs to mention the new locale.

