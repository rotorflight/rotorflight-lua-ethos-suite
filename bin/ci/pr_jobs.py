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

* `LUA_JOBS` is the uniform one -- checkout, install lua5.3, run a single
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
    """A job that checks out, installs lua5.3 and runs one harness."""

    id: str
    name: str
    step: str
    script: str
    rationale: str




LUA_JOBS = [
    LuaJob(
        id='flight-record',
        name='Flight record across a link loss',
        step='Check the flight record behaviour',
        script='bin/flight_record/verify_flight_record.lua',
        rationale=r'''A flight is a state machine that only misbehaves across a link loss, which
no build and no package step can reach. Before this job the repository had no
way to run a Lua check at all, so this is where the flight-record behaviour
is pinned: a brief in-flight drop stays one record, and a pack swap stays
two.
'''
    ),
    LuaJob(
        id='atomic-writes',
        name='Settings survive an interrupted write',
        step='Check the write path',
        script='bin/storage/verify_atomic_writes.lua',
        rationale=r'''Every file the suite owns was opened for writing directly, and io.open(path,
"w") truncates on open -- so a radio switched off mid-save left
settings.ini at 0 bytes or half a section, and the INI reader skips lines it
does not recognise, which means the pilot's settings came back as the
defaults with nothing reported anywhere. A build and a package step cannot
reach that, and no page shows it: this is where the write path is pinned.
The first case in the check goes red on the pre-fix ini.lua.
'''
    ),
    LuaJob(
        id='esc-guard-retry',
        name='ESC tiles recover from a failed read',
        step='Check that a failed ESC read is retried',
        script='bin/esc_guard/verify_esc_guard_retry.lua',
        rationale=r'''The ESC forward-programming tiles are gated by a guard that has to retry a
failed MSP read. That retry reaches neither a build nor a package step, so
it is pinned here. #2387
'''
    ),
    LuaJob(
        id='msp-queue',
        name='MSP queue after an aborted request',
        step='Check the MSP queue behaviour',
        script='bin/msp_queue/verify_msp_queue.lua',
        rationale=r'''An MSP request that is abandoned between two of its frames used to leave
the shared TX buffer occupied, after which no request could be framed at all
-- every configuration page then hung until the script was reloaded. No
build and no package step reaches that: it needs a queue, a clock and a
link that stops answering, so the behaviour is pinned here instead.
'''
    ),
    LuaJob(
        id='log-flush-retry',
        name='Flight log keeps samples it could not write',
        step='Check that an unwritable card does not discard the buffer',
        script='bin/logging/verify_log_flush_retry.lua',
        rationale=r'''A flight log is the pilot's evidence after a crash, and both ways it could
lose rows were silent: an io.open that failed emptied the buffer, and a failed
write() trimmed the rows it had just failed to persist. Neither leaves a trace
-- the CSV looks like a log that worked and simply recorded nothing.

Only a card that cannot be written reaches either path, and that is not
something a build or a package step can stage. So the real logger is driven
here with io.open and the handle's write() as the seams, and every sample is
identifiable, so "were rows 1 to 20 written?" is a fact about the bytes.

13 of its 18 cases go red on the pre-fix logging.lua; the ones that do not
pin the healthy path and the once-per-streak report.
'''
    ),
    LuaJob(
        id='clock-budgets',
        name='Background task drain budgets',
        step='Check the drain budgets',
        script='bin/perf/verify_clock_budgets.lua',
        rationale=r'''Three drain loops run inside one background-task wakeup with no yield point
in between, and each was bounded by a wall-clock deadline set well above what
the work needs -- on a single-core MCU competing with Ethos's C++ UI thread,
the budget is UI latency. Nothing could see that, and nothing could see the
other half: that a deadline read only *between* polls cannot bound one
transport.mspPoll() call, which on S.Port walks the sensor's whole native
frame queue. This harness drives the three loops against a permanently full
queue and a clock that charges real time per frame, so it measures the budget
instead of trusting it. The last group is the other half -- bounding the
poll must not break reply assembly, which is what says how far a budget may
be cut at all.
'''
    ),
    LuaJob(
        id='msp-codec-battery',
        name='A short MSP payload is reported, not decoded',
        step='Check the codec and the battery decoders',
        script='bin/msp_battery/verify_msp_battery.lua',
        rationale=r'''Every MSP decoder in the suite funnels through lib/mspcodec.lua, and the one
primitive there was not bounds-safe: readU8 returned nil for a byte past the
end of the payload where readS8/readU16/readS16/readU32 all substituted 0.
That nil was not a missing value. The smartfuel decoder divided a readU8
result by 1000, and tasks/msp/queue.lua calls processReply with no pcall and
there is none in the task path either, so a short reply raised out of the
background task instead of being reported. The battery decoder had the softer
version: a nil or a zero standing in for a profile capacity, in a config that
still passed session.lua's `if not session.batteryConfig` guard because that
guard sees the table and not its contents. A build cannot reach any of that,
and a radio only produces a short reply under conditions nobody can script on
demand, so the payload lengths are pinned here against the firmware handler's
own byte counts instead. Cases 4, 5 and 6 go red on the pre-fix sources.
'''
    ),
    LuaJob(
        id='tool-ui-lazy',
        name='Tool UI not loaded at boot',
        step="Check the tool's load timing",
        script='bin/tool_ui/verify_tool_ui_lazy.lua',
        rationale=''
    ),
    LuaJob(
        id='tool-ui-no-extra-msp',
        name='Tool adds no MSP requests and accumulates nothing',
        step='Check the MSP request pattern over repeated tool cycles',
        script='bin/tool_ui/verify_no_extra_msp.lua',
        rationale=r'''Deferring the tool's UI raises the obvious question: does it add MSP
traffic, and does anything accumulate per open/close cycle? This harness
counts the requests at bus.publish over three full tool cycles plus 100
wakeups inside the guarded menu. It goes red if the guards stop latching
(a sabotaged guard produces 309 requests instead of 6).
'''
    ),
    LuaJob(
        id='field-layout',
        name='Field layout slot pooling and lifecycle',
        step='Check field layout slot pooling and lifecycle',
        script='bin/field_layout/verify_field_layout.lua',
        rationale=r'''Ethos form widgets retain closures across form.clear(), so app/field_layout.lua
pools accessor slots to prevent unbounded closure growth across repeat page visits.
This job checks poolStats(), slot pooling across pages and visits, and safe detachment
of dataRef/controlRef on releaseRuntime().
'''
    ),
    LuaJob(
        id='dashboard-image-caches',
        name='Dashboard image cache eviction and theme reload',
        step='Check dashboard image cache behaviour',
        script='bin/dashboard/verify_image_caches.lua',
        rationale=r'''Widgets and objects load bitmaps on demand, and clearCaches()'s images
branch previously had no caller anywhere -- so every decoded dashboard
bitmap survived theme reloads, model changes and widget close. The fix
wires clearThemeCache() to pass images = true, adds an LRU bound to the
decoded-bitmap map, and provides a clearer registry for modules like
objects/image/model.lua.
'''
    ),
    LuaJob(
        id='msp-disconnect-gc',
        name='MSP queue on disconnect and the per-message GC',
        step='Check the disconnect and GC behaviour',
        script='bin/msp_gc/verify_msp_disconnect.lua',
        rationale=r'''A disconnect used to leave the MSP request queue holding everything an open
page had queued, so the next handshake queued FIFO behind a backlog that no
flight controller could answer any more. And every completed message forced
a full GC cycle -- a call section 9 of the lifecycle doc had already measured
as buying nothing. Both need a session task and a collector that can be
observed, which no build or package step provides.
'''
    ),
    LuaJob(
        id='stack-bounds',
        name='Bus publish is bounded, stack minimum is tracked',
        step='Check the publish recursion bound and the stack minimum',
        script='bin/stack/verify_stack_bounds.lua',
        rationale=r'''The bus is the only channel between the tool, the dashboard and the
background task, and publish() calls its handlers synchronously -- a
handler that publishes back into the same topic recurses, and in the
reference Lua VM every Lua-to-Lua call is one C stack level. This harness
drives a real cycle and asserts it terminates at the guard rather than at
the VM's own "C stack overflow" (which is what happens without it: 197
handler calls), and that the memory log reports the smallest
mainStackAvailable it has ever seen.
'''
    ),
    LuaJob(
        id='dialog-lifecycle',
        name='Dialog teardown when a page is left',
        step='Check the dialog teardown',
        script='bin/dialog_lifecycle/verify_dialog_lifecycle.lua',
        rationale=r'''Leaving a page -- with the Back key, or by closing the tool -- ran the
page's dialog teardown on a form Ethos had already stopped updating, and a
save/reload confirmation that was still up outlived the page behind it with
an OK button that did nothing. Neither is visible from a build: the first
needs a form that refuses writes, the second needs a dialog handle that
something else has to own. So the pages are loaded for real here, under a
form whose writes raise once teardown starts.

Five of its cases go red on the pre-fix pages, each naming the line it
fails on.
'''
    ),
]

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

      - name: Install Lua 5.3
        run: sudo apt-get update && sudo apt-get install -y lua5.3

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Prove the width check can go red
        run: python bin/fblstatus/verify_arming_flag_widths.py --self-test

      - name: Check the arming flag mask and the page's use of it
        run: lua5.3 bin/fblstatus/verify_arming_flags.lua

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
