# Theme integration checks

Install Python 3.11 or newer and Lupa (`python -m pip install lupa==2.8`). Run
from the repository root:

```text
python -m unittest discover -s tests/themes -p 'test_*.py' -v
```

Each new theme supplies `test_<folder>_registration.py` and a matching
`<folder>_registration.json`. Its `<folder>_registration.md` documents the exact
command for that theme. The wrappers use the identical `theme_registration.py`
helper, so independently submitted theme PRs do not replace a shared selection
manifest or test module. Multiple wrappers can coexist without changing globals.

The fixture executes the target Suite's loader, settings normalization, pages,
metadata and configure module. It uses the actual package locale resolver and
generated English catalog. Checks cover names, minimum-size filtering, phase
paths, global/model choices, settings save/reopen, unrelated-data preservation,
cleanup, and three documented previews. No other custom theme is required.

`RFSUITE_TEST_ROOT` optionally selects another Suite repository containing
`src/rfsuite`. Optional local dependencies can be placed in this checkout's
`build/test-deps`.

Storage, the radio UI, and phase painting are mocked here. The documented
previews separately execute actual phase code and the Suite engine with desktop
fonts. Neither substitutes for physical-radio acceptance. Existing regression
tests remain present for their original coverage.
