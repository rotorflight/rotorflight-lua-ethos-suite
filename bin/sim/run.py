#!/usr/bin/env python3
"""Runs the suite's simulator tests (bin/sim/test_*.py) with the test runner of
FrSkyRC/ethos-tools (simulation/tests/run_tests.py), on a simulator or a radio.

  python bin/sim/run.py --deployed [TEST...]
      The simulator of .vscode/settings.json (ethos.board / ethos.protocol), on a copy
      of the folder deploy.py wrote (simulators/<BOARD>_<PROTOCOL>@<release>). Deploy
      first. The copy keeps the test from changing your simulator's models.

  python bin/sim/run.py --port 8765 [TEST...]      a run_wasm.js --serve already running
  python bin/sim/run.py --port 8766 [TEST...]      a radio_remote.py --serve already running
  python bin/sim/run.py --simulator X.js --root-directory DIR [TEST...]

Every other option is the one of run_tests.py (--option name=value, --out DIR...).
ethos-tools is looked for in --ethos-tools DIR, then $ETHOS_TOOLS, then beside this
repository (../ethos-tools). Its tests need: pip install -r simulation/tests/requirements.txt
"""

import json
import os
import shutil
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))


def take(argv, name):
    """Removes `name VALUE` from argv and returns VALUE, or None."""
    if name not in argv:
        return None
    index = argv.index(name)
    if index + 1 >= len(argv):
        sys.exit(f'{name} needs a value')
    value = argv[index + 1]
    del argv[index:index + 2]
    return value


def ethos_tools_tests(given):
    for folder in (given, os.environ.get('ETHOS_TOOLS'), os.path.join(REPO, '..', 'ethos-tools')):
        if folder:
            tests = os.path.join(os.path.abspath(folder), 'simulation', 'tests')
            if os.path.isfile(os.path.join(tests, 'run_tests.py')):
                return tests
    sys.exit('No ethos-tools clone: git clone https://github.com/FrSkyRC/ethos-tools beside this '
             'repository, or give its folder with --ethos-tools DIR or $ETHOS_TOOLS')


def extension_cache():
    if sys.platform == 'win32':
        base = os.path.join(os.environ.get('APPDATA', ''), 'Code', 'User')
    elif sys.platform == 'darwin':
        base = os.path.expanduser('~/Library/Application Support/Code/User')
    else:
        base = os.path.expanduser('~/.config/Code/User')
    return os.path.join(base, 'globalStorage', 'bsongis.ethos', 'cache')


def deployed_target():
    """(simulator .js, copy of the deployed radio folder) from .vscode/settings.json."""
    with open(os.path.join(REPO, '.vscode', 'settings.json'), encoding='utf-8') as f:
        settings = json.load(f)
    name = f'{settings["ethos.board"]}_{settings["ethos.protocol"]}'
    release = settings.get('ethos.release') or settings.get('ethos.version')
    radio = os.path.join(REPO, settings.get('ethos.simulatorsFolder', 'simulators'), f'{name}@{release}')
    if not os.path.isfile(os.path.join(radio, 'scripts', 'rfsuite', 'main.lua')):
        sys.exit(f'Nothing deployed in {radio}: run .vscode/scripts/deploy.py first (AGENTS.md section 12)')
    simulator = os.path.join(extension_cache(), f'{name}.js')
    if not os.path.isfile(simulator):
        sys.exit(f'No {simulator}: run "Ethos: Start" once in VS Code, or use --simulator')
    copy = os.path.join(tempfile.mkdtemp(prefix='rfsuite-sim-'), name)
    shutil.copytree(radio, copy)
    return simulator, copy


def main():
    argv = sys.argv[1:]
    tests = ethos_tools_tests(take(argv, '--ethos-tools'))
    copy = None
    if '--deployed' in argv:
        argv.remove('--deployed')
        simulator, copy = deployed_target()
        argv += ['--simulator', simulator, '--root-directory', copy]
    if '--out' not in argv:
        argv += ['--out', os.path.join(REPO, '.vscode', 'logs', 'sim-tests')]  # git-ignored

    sys.path[:0] = [HERE, tests]
    import run_tests
    run_tests.TESTS_DIR = HERE  # our tests instead of the ones of ethos-tools
    sys.argv = [sys.argv[0]] + argv
    try:
        run_tests.main()
    finally:
        if copy:
            shutil.rmtree(os.path.dirname(copy), ignore_errors=True)


if __name__ == '__main__':
    main()
