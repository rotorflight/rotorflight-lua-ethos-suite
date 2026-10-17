"""The job list of .github/workflows/pr.yml, as data.

`pr.yml` used to be edited by hand, and every pull request that added a
harness job inserted it at the same place -- between two existing jobs. Two
open pull requests that did the same thing therefore collided, repeatedly, on
context lines that had nothing to do with either change. #2414's squash
resolved that collision by concatenating two job names onto one `runs-on:`
block; the file then failed to load as a workflow, and the run on master had
zero jobs. #2416's squash repeated it. Both are recorded in
verify_pr_workflow.py, which is the check that keeps this file honest.

So `pr.yml` is generated from here. Adding a harness means adding a LuaJob
below and running `python bin/ci/verify_pr_workflow.py --write`; nothing edits
`pr.yml` by hand any more, and two pull requests can no longer collide on it
because the generator puts each job where the registry says.

Two kinds of entry, because the jobs are not all the same shape:

* `LUA_JOBS` is the uniform one -- checkout, install lua5.4, run a single
  harness. That is what every new behaviour fix needs, so it is modelled
  properly: the rationale is the reason the harness exists, and it is the
  part that has to survive being moved into a Python string.

* `VERBATIM_JOBS` keeps its YAML verbatim. Those four jobs need a matrix, an
  env block, or several commands, and modelling GitHub Actions step semantics
  in Python would add a second thing to review without making the file any
  less of a single source. They are still generated in the sense that nothing
  outside this file decides what they contain. The literals are raw, because a
  shell command in them ends with a backslash and Python would otherwise read
  that as a line continuation and fold the command onto one line.

The rationale is kept line for line as it reads in `pr.yml`, including its
wrapping, because that text is written to be read next to the job it
explains.
"""

from typing import NamedTuple


class LuaJob(NamedTuple):
    """A job that checks out, installs lua5.4 and runs one harness."""

    id: str
    name: str
    step: str
    script: str
    rationale: str




# The harness jobs are read from their own <stem>.ci.json files, one next to
# each harness script (issue #2585). Adding a harness no longer edits this file.
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from harnesses import discover as _discover  # noqa: E402

LUA_JOBS = _discover(_os.path.abspath(_os.path.join(_os.path.dirname(_os.path.abspath(__file__)), '..', '..')))


VERBATIM_JOBS = [
    # create-zip
r'''  # Per-language PR builds (mirrors push.yml behavior)
  create-zip:
    name: Build PR ZIP (${{ matrix.lang }})
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        # keep this in sync with push.yml (add locales as translations land)
        lang: [en, de, es, fr, it, nl, pt-br, no, cs, pl, he, zh-cn]

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Set build variables (PR version)
        run: |
          PR_NUMBER='${{ github.event.pull_request.number }}'
          echo "GIT_VER=PR-${PR_NUMBER}" >> $GITHUB_ENV

      - name: Create rotorflight-lua-ethos-suite-lite-${{ env.GIT_VER }}-${{ matrix.lang }}.zip
        run: |
          python bin/package/build_package.py \
            --lang '${{ matrix.lang }}' \
            --artifact-version '${{ env.GIT_VER }}' \
            --artifact-name 'rotorflight-lua-ethos-suite-lite-${{ env.GIT_VER }}-${{ matrix.lang }}.zip' \
            --output-dir .

      - name: Validate ETHOS package manifest
        run: |
          python bin/package/validate_ethos_manifest_zip.py \
            'rotorflight-lua-ethos-suite-lite-${{ env.GIT_VER }}-${{ matrix.lang }}.zip'

      - name: Upload per-locale ZIP
        uses: actions/upload-artifact@v4
        with:
          name: rotorflight-lua-ethos-suite-lite-${{ env.GIT_VER }}-${{ matrix.lang }}
          path: rotorflight-lua-ethos-suite-lite-${{ env.GIT_VER }}-${{ matrix.lang }}.zip
          if-no-files-found: error
'''
    ,
    # fblstatus
r'''  # A Diagnostics page cannot be looked at from a pull request, and the one
  # that broke was invisible by construction: app/pages/diagnostics_fblstatus.lua
  # joined every active arming-disable flag into one value-column string, and
  # that column is the narrow right-hand half of the line, so on a 480x320
  # radio the reason the model would not arm was clipped off the right edge.
  #
  # The mask arithmetic now lives in lib/arming_flags.lua with no dependency on
  # form or lcd, so it can be stepped here; the widths of the translated strings
  # are the half that needs the locale files, and the two run together because
  # neither one is worth anything without the other.
  fblstatus:
    name: Arming flags readable at any resolution
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Lua 5.4
        run: sudo apt-get update && sudo apt-get install -y lua5.4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Prove the width check can go red
        run: python bin/fblstatus/verify_arming_flag_widths.py --self-test

      - name: Check the arming flag mask and the page's use of it
        run: lua5.4 bin/fblstatus/verify_arming_flags.lua

      - name: Check every locale's flag strings against the row widths
        run: python bin/fblstatus/verify_arming_flag_widths.py
'''
    ,
    # sensor-table-completeness
r'''  # tasks/elrs_sensors.lua's parseFrame() stops at the first appId it has no
  # decoder for and cannot skip it -- the pair's byte width lives only in
  # src/rfsuite/lib/elrs_sensor_table.lua. So one appId the table is missing
  # silently costs every sensor packed after it in the same frame, and the
  # symptom looks like a dead sensor. Nothing in the tree could see that, so
  # the table is compared against the firmware's TLM_SENSOR(...) list.
  #
  # The firmware file is read from a pinned snapshot tag, so a firmware that
  # adds an appId shows up here as a deliberate change to this check rather
  # than as a frame-walk abort on a pilot's radio.
  sensor-table-completeness:
    name: Sensor table completeness
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Prove the check can go red
        run: python bin/telemetry/verify_sensor_table.py --self-test

      - name: Check every broadcast appId has a decoder
        run: python bin/telemetry/verify_sensor_table.py
'''
    ,
    # i18n-fit
r'''  # A string too wide for where it is shown is cut off on the radio: a form label
  # runs under its field, a menu tile label ends in "...". max_length caps a
  # translation at the English character count, which says nothing about pixels,
  # so German and Polish labels overflowed while passing it. check-fit.py measures
  # every locale's strings against the budget of the place each key is used, with
  # character widths measured on the X18 (the smallest screen).
  i18n-fit:
    name: i18n strings fit the X18
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Prove the check can go red
        run: python bin/i18n/check-fit.py --self-test

      - name: Check every locale fits
        run: python bin/i18n/check-fit.py
'''
    ,
    # documentation-rule
r'''  # The rule in .agents/rules/documentation.md asks that a change a pilot can observe
  # updates its page file in the same pull request, and that a pull request which needs
  # no documentation change says why. Nothing checked either half, so both rested on
  # the author remembering at the moment they are least likely to.
  #
  # The check is deliberately narrower than the rule says, because no static check can
  # decide what a pilot can observe: it asks nothing of a pull request that changes
  # nothing under src/, passes one that changes src/ and also docs/, and passes one
  # that changes src/ and no docs/ only if its body carries a `Documentation:` line of
  # its own. Whether that reason is a good one is the reviewer's call.
  documentation-rule:
    name: Documentation rule
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          # the check diffs against the base commit, which a shallow clone does not carry
          fetch-depth: 0

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Prove the check can go red
        run: python bin/docs/verify_documentation_rule.py --self-test

      - name: Write the pull request body to a file
        # through the environment, never interpolated into the script: a pull request
        # body is text anybody can write
        env:
          PR_BODY: ${{ github.event.pull_request.body }}
        run: printf '%s' "$PR_BODY" > pr-body.txt

      - name: Check the documentation rule
        run: |
          python bin/docs/verify_documentation_rule.py \
            --base '${{ github.event.pull_request.base.sha }}' \
            --body-file pr-body.txt
'''
    ,
    # i18n-tags
r'''  # A tag that does not resolve is shown on the radio as the raw text "@i18n(...)@",
  # and a hardcoded English label draws perfectly in every language, so neither
  # shows up in a build. check-tags.py fails when a @i18n tag in src/ has no key in
  # en.json. check_translations.py counts the literals that never reach the translator
  # and fails when that count grows past its baseline (71 on master, 2026-10-11): the
  # count is a ratchet, not a target, so the existing strings are reported rather than
  # blocking. --self-test proves the detector finds and keeps quiet where it should.
  i18n-tags:
    name: i18n tags resolve and no new hardcoded labels
    runs-on: ubuntu-latest
    # Read-only token: the checkers run code from the pull request.
    permissions:
      contents: read

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          persist-credentials: false

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Prove the translation check can go red
        run: python bin/i18n/check_translations.py --self-test

      - name: Check every @i18n tag resolves against en.json
        run: python bin/i18n/check-tags.py

      - name: Check the untranslated-literal ratchet
        run: python bin/i18n/check_translations.py
'''
    ,
    # pr-workflow-drift
r'''  # pr.yml used to be edited by hand, and every pull request that added a
  # harness job put it in the same place in the file. Three of them were open
  # at once on 2026-09-30, and each collision cost a resolution rather than a
  # merge. Two of those resolutions were wrong in a way nothing caught:
  # #2414's squash left dashboard-image-caches with a name and no runs-on, and
  # #2416's squash did the same to field-layout, so the file stopped loading as
  # a workflow and the run on master reported failure with zero jobs.
  #
  # The file is now rendered from bin/ci/pr_jobs.py. This job is the other half
  # of that: a registry that is edited without regenerating leaves the two
  # disagreeing, and the next pull request to add a job inherits the old file
  # and the same collision. It also pins the shape that broke twice -- every job
  # needs a runs-on and at least one step.
  #
  # The self-test proves the checks can go red: it removes a runs-on from a
  # rendered job, edits a line of the committed file, and adds a job naming a
  # harness that does not exist, and each of those has to be reported.
  pr-workflow-drift:
    name: The pull request workflow matches its registry
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Prove the check can go red
        run: python bin/ci/verify_pr_workflow.py --self-test

      - name: Check pr.yml against the registry
        run: python bin/ci/verify_pr_workflow.py
'''
    ,
]
