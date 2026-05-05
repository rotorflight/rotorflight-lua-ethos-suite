# Developer Environment Setup (Generic)

This guide focuses on a **generic, cross-platform** setup. Some tooling may work best on Windows, but the requirements below are OS-agnostic.

## Core Requirements
- **Git**: for cloning and working with the repo.
- **Python 3.11+**: used by build and helper scripts (CI uses 3.11).
- **pip**: to install Python dependencies.

## Optional Tools (Depending on What You Work On)
- **Lua formatter**: `lua-format` is required by `bin/format_lua.py`.
- **Tk**: required if you run the updater GUI locally (Python `tkinter`).
- **PyInstaller**: required if you build the standalone updater executable.
- **Audio tooling** (sound packs):
  - `sox` Python module.
  - `google-cloud-texttospeech` Python module.
  - Google Cloud credentials (if generating audio packs).

## VS Code Extensions
If you use VS Code, install the following extensions:
- **Ethos** (required): provides Ethos/Lua workflow support for this repo.
- **pydebug** (required): Python debugging support for tooling scripts.

If there are additional required extensions for your workflow, add them here.

## Quick Verification
Run these in your shell to confirm the basics:

```bash
git --version
python --version
python -m pip --version
```

## Common Tasks and Dependencies
### Python packages used by repo tooling
Install the shared development requirements:

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

Notes:
- Use `pyserial`, not the unrelated `serial` package.
- `pywin32` is Windows-specific and is skipped automatically by `requirements.txt` on other platforms.
- On Windows, the HID DLL step may still be needed if `hidapi.dll` is not found.
- On macOS, install the native HID library first: `brew install hidapi`.

### 1) i18n sync
Used in CI and when updating translations:

```bash
python bin/i18n/build-single-json.py --only en
```

### 1b) Menu manifest generation
Use this when editing `bin/menu/manifest.source.json`:

```bash
python bin/menu/generate.py
python bin/menu/generate.py --check
```

### 2) Resolve i18n tags (staging/packaging)
Used in CI packaging and dev workflow:

```bash
python .vscode/scripts/resolve_i18n_tags.py --help
```

### 3) Lua formatting
`bin/format_lua.py` requires `lua-format` on PATH.

```bash
lua-format --version
python bin/format_lua.py --help
```

### 4) Updater GUI (optional, in updater repo)
The updater uses Python + Tk and has its own requirements list:

```bash
python -m pip install -r rotorflight-lua-ethos-suite-updater/src/requirements_updater.txt
python rotorflight-lua-ethos-suite-updater/src/update_radio_gui.py
```

If Tk is missing, install your platform’s Tk package or Python build with Tk support.

### 5) Updater standalone build (optional)
Requires PyInstaller:

```bash
python -m pip install pyinstaller
```

See `rotorflight-lua-ethos-suite-updater/src/README.md` for full build steps.

### 6) Sound pack generation (optional)
Requires additional Python modules and external service credentials:

```bash
python -m pip install sox google-cloud-texttospeech
python bin/sound-generator/generate-googleapi.py --help
```

## Notes
- If you are on a platform where a script does not run, prefer running the CI-friendly Python scripts directly (the `.bat` convenience scripts are Windows-first).
- This repo does not enforce a single package manager or virtualenv workflow. Use whatever is standard for your environment.
