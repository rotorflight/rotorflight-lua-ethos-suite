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
        id='esc-target-selector',
        name='The ESC selector offers only the ESCs that exist',
        step='Check that a single-ESC setup shows no dead ESC rows',
        script='bin/esc_target_selector/verify_esc_target_selector.lua',
        rationale=r'''Every 4-way forward-programming page -- AM32, BLHeli_S, Bluejay,
FlyRotor, Scorpion, HW5, OMP, XDFly, YGE, ZTW -- opens on
app/pages/esc_forward_4way.lua, which asks the FC how many ESCs there are and
then built its selector. It built ALL FOUR rows ("ESC 1".."ESC 4") and greyed
out the surplus with button:enable(i <= count), so a single-ESC helicopter saw
three dead lines, with nothing in the UI saying why.

A control that cannot be used is not a disabled control, it is noise, and on a
480x320 screen it was a third of the page. The selector now builds only the ESCs
that exist, and with exactly one ESC there is no choice to offer, so there is no
selector at all and the page goes straight to that ESC.

The second half is where the trap is. The FC's answer has THREE distinguishable
states, not two: a count of 1, no count at all because the reply carried no
motor_count_blheli, and a read that failed. Collapsing the last two into "one
ESC" would enter pass-through on a two-ESC helicopter because the read came back
thin, so an unknown count keeps the selector and keeps this page's long-standing
conservative default of ESC 1 only. The harness pins all three states.

No existing harness loads this page: the other ESC harnesses stub it precisely
to avoid its os.clock() delays (verify_esc_signature.lua:464-470), which is why
the dead rows survived. This one loads it from its path and drives the real
header and close_key.

The issue's other half -- dropping the parsed cache on page exit -- needs no
code and did not get any. It has been in place since the total rewrite (#2256,
2026-08-07), seventeen days before #2338 was filed: esc_forward_vendor.lua:124-156
resets the FBL control with clearQueue, closes the dialog, nils pendingData and
pendingError, disposes the runtime, drops every handler, unloads the codec from
package.loaded and collects. open() issues a fresh read on every call
(esc_forward_vendor.lua:295), so no cache can survive. One check here pins that
reset so the claim keeps being true.

5 of its 18 checks are gates. Pass --self-test to prove that: it cuts the four
pieces out, re-runs every check against the sabotaged page and requires each gate
to turn red, comparing verdicts BY NAME. Getting there took three corrections
that are worth recording: nine checks were marked gates that cannot fail; the
sabotage was missing the enable expression, so the dead-row check stayed green;
and with the row bound reverted but the new reply callbacks left in, pass 2
CRASHED -- the pre-fix button:enable(i <= targetCount) raises on a nil count,
which is why its "targetCount = 1" on a failed read was load-bearing and not
tidiness.
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
    # Registered here because the job was added to pr.yml by hand, so the
    # generator did not know about it and the drift check has been red on master
    # since #2432 landed. Any --write dropped this job from the workflow; the
    # text below is master's, verbatim.
    LuaJob(
        id='profile-anchor',
        name="A page's data stays tagged with the profile it came from",
        step='Check the profile anchor across a switch during a read',
        script='bin/page_runtime/verify_profile_anchor.lua',
        rationale=r'''A page tags its data with the profile it was read for, and the tag used to
be taken when the read finished rather than when it started. A pilot who
switched profile while that read was in flight therefore got the previous
profile's values on screen, anchored to the new profile -- and because the
anchor matched, nothing ever reloaded. Saving then writes the old profile's
values into the new one.

Only a switch landing inside an MSP round-trip reaches it, which no build and
no package step can stage. So MSP answers are held here rather than delivered
inline, and the session.update is delivered while a read is genuinely in
flight. Inline delivery makes the whole file vacuous.

5 of its 17 cases go red on the pre-fix page_runtime.lua.
'''
    ),
    LuaJob(
        id='tool-focus',
        name="The Tool button hands a page a callable focus function",
        step='Check the Tool button passes a page its focus function',
        script='bin/page_runtime/verify_tool_focus.lua',
        rationale=r'''Every page's onTool is function(focusFn), and calls focusFn() when its
dialog closes or is cancelled. The header's Tool button called it as
runtime:onTool(focus), so the page got the runtime table as focusFn and
calibrating the accelerometer ended in "focusFn is not callable (a table
value)". This presses the real page_runtime.lua's Tool button and closes
the dialog the way the pages do; 4 of its 5 checks go red on the pre-fix
page_runtime.lua.
'''
    ),
    LuaJob(
        id='wakeup-allocations',
        name='Wakeup path allocates nothing per call',
        step='Check the wakeup allocation paths',
        script='bin/allocation_churn/verify_allocation_churn.lua',
        rationale=r'''The dashboard wakeup path runs several times a second and session.update
is published at up to 20 Hz, so a table rebuilt per call there is the
sawtooth in the '[bgtask mem] lua=' log rather than a detail. Three such
sites were removed: the subscriber copy in lib/bus.lua, the name table and
its result table in getSensorStats(), and the per-call closure in
transformValue(). #2384.

No build and no package step reaches this -- it needs the collector held off
and a loop that calls the function thousands of times, which is what the
harness does. Every allocation assertion is paired in both directions: the
current code has to come out under the bound and the removed code over it,
on every run. A bound that both sides meet proves nothing, and the harness
carries the removed implementations precisely so that can be seen. The same
run also pins what a pooled iteration copy can get wrong -- a handler
unsubscribed long ago must not come back through a leftover slot -- and the
one value the change alters, an rssi box reading its own min/max instead of
link quality's.

Pass --self-test to assert only that the bounds still have teeth.
'''
    ),
    # Appended after #2435 merged, so this entry is a pure addition to the
    # registry rather than a re-registration of profile-anchor: that job arrived
    # in master with #2435 and the text above is now master's.
    LuaJob(
        id='gc-pause',
        name='The incremental collector is tuned, and reads no pause it did not set',
        step='Check the collector pause and the forced collects',
        script='bin/gc_pause/verify_gc_pause.lua',
        rationale=r'''The collector's pause decides when a cycle starts: live * pause / 100.
The default is 200, so the heap may reach twice what is live before anything is
reclaimed at all, while Ethos kills a script whose heap passes its limit (#2295).
Lowering it is a one-line change -- but the one line has a foot-gun in it, and
that is what this pins:

`collectgarbage("setpause", n)` returns the PREVIOUS value, and with the
argument omitted it does not read the current one, it SETS THE PAUSE TO 0.
Pause 0 is "collect as constantly as possible", the opposite of the intent.
Measured on Lua 5.3.6 and on 5.4 (what Ethos runs), and the first case here asserts it
rather than trusting it, because main.lua's own comment cites the behaviour and
a future interpreter could change it.

So the applied value is printed at boot instead of read back, and no file under
src/ may call either setter without an explicit value. The harness also fixes
where the call goes -- before background_task.init(), so the collector is on the
new schedule while the subsystems allocate -- and holds the line that separates
the justified forced collects from the hot path: Queue:_finish() must stay
clean, Queue:clear() and the three ESC dispose paths must keep theirs.

Pass --self-test to prove every one of those can go red: each check is aimed at
a sabotaged copy of main.lua, at a planted bare setter, and at a queue.lua with
its teardown collect cut out.
'''
    ),
    LuaJob(
        id='root-close-key',
        name='The physical Back key closes the suite from every screen',
        step='Check the root menu close key',
        script='bin/tool_ui/verify_root_close_key.lua',
        rationale=r'''Every screen but one installed a handler for the physical Back/Close key. The
root menu installed none, on the stated assumption that Ethos's own default
closes the tool on the first press. It does not -- that default takes two, the
first dropping the form's input focus -- so the root menu had two ways out that
disagreed with each other: the on-screen Menu button left in one press, the
hardware RTN in two. Neither a build nor a package step reaches any of it.

The harness drives the real tool.lua through registerSystemTool, create() and
event() -- not menu_container directly, because tool.lua's forwarding is part of
what is being pinned -- and asserts that RTN and EXIT reach goBack() at the root,
that goBack() is the same path the back button takes, that a long ENTER, a model
key and a touch event are still passed through untouched, and that RTN in a
submenu pops one level without exiting.

Seven of its seventeen cases go red on the pre-fix file. Pass --self-test to
prove that rather than take it on trust: it re-runs the identical sequence
against a copy of app/menu_container.lua with the pre-fix root branch put back
and requires every one of the seven to fail.
'''
    ),
    LuaJob(
        id='governor-profile-write',
        name='A governor profile is never written from an incomplete table',
        step='Check the governor profile write guard',
        script='bin/governor_profile/verify_governor_profile_write.lua',
        rationale=r'''lib/msp_governor_profile.lua encoded every field as `data[name] or 0`, so a
table missing a key became a struct of zeros -- governor_headspeed 0,
governor_max_throttle 0 -- and every one of those is a value the firmware
accepts as in range. It re-runs its own validateAndFixServoConfig() on it and
reports success. There is nothing in the write for a pilot to notice.

What this pins is that the encoder refuses instead of inventing, and -- the half
that matters -- that the refusal is not merely returned but acted upon: a codec
that declines to build a message is a REFUSED write in app/page_runtime.lua, not
a message with no payload. Asserting on encode() alone would pass while the
runtime published the nil, so the harness drives the real page_runtime with the
real codec and reads what went onto the bus.

No build and no package step reaches it. The load gate that already existed --
any source read failing keeps loaded == false and canSave() false -- is pinned
too, so a later change cannot trade one protection for the other.

Cases 2, 3 and 4 go red on the pre-fix codec. Pass --self-test to prove that
rather than take it on trust: it puts a copy of the codec with the pre-fix
encode() in the same seat and requires it to build a 17-byte all-zero payload
from an empty table AND requires page_runtime to publish it.
'''
    ),
    LuaJob(
        id='instruction-budget',
        name='Callbacks stay under the Ethos instruction limit',
        step='Check the Ethos instruction budget',
        script='bin/perf/verify_instruction_budget.lua',
        rationale=r'''Ethos aborts any Lua callback that runs 20000 VM instructions ("Max
instructions count reached"), and nothing on the radio says how close one
runs. This drives the real dashboard widget through every theme and flight
state, and the real background task through boot, link up, steady CRSF with
ELRS frames, an ELRS backlog and link down, and the real system tool through
every menu and every page (opened cold, read replies served by the MSP
codecs' simulator fixtures), counting instructions with a debug hook on
desktop Lua. Any callback at or over the limit fails, so a theme with too
many boxes, a new per-tick cost, or a page that builds its form in one
oversized pass is caught here instead of as stalled frames, a dropped
background tick in flight, or a page that never draws. The Ports page did
exactly that before this check covered the app: its function lists cost
~25k instructions with 4 serial ports and ~255k with 12, in one wakeup.
'''
    ),
    # Appended after #2335 turned out to be already implemented in master: the
    # gate has been in esc_forward_vendor.lua since the rewrite, so this entry
    # adds no gate of its own. It pins the one that is there -- a defect that
    # only appears when a pilot opens the wrong tile reaches nothing else here,
    # and the firmware cannot cover the BLHeli_S/Bluejay pair.
    LuaJob(
        id='esc-signature',
        name="An ESC editor never opens on another vendor's ESC",
        step='Check the ESC forward-programming signature gate',
        script='bin/esc_signature/verify_esc_signature.lua',
        rationale=r'''AM32, BLHeli_S and Bluejay are three tiles of tool.lua's esc_forward_menu that all
carry escProtocolId = 1, so the menu guard cannot tell them apart, and all three
answer on MSP 217/218 behind the same two-byte header. A pilot who opens the
wrong one gets a complete editor full of another ESC's bytes and a working Save.

The gate is app/pages/esc_forward_vendor.lua:228-236. isCompatibleEsc() is called
in the read's reply callback at :281-295, sets pendingError = {kind = "signature"}
and never sets pendingData, so buildEditor() is never reached -- no runtime means
no fields, no Save button and no MSP 218 anywhere. All ten ESC tiles declare a
signature to check against, and the two BLHeli-family ones need their
main_revision as well, because they share 0xC1 and nothing else separates them.

The flight controller refuses a cross-signature write too: is4wayParamBufferValid()
at src/main/sensors/esc_sensor.c:4591-4622 checks signature, protocol version and
length, and escCommitParameters() turns a false into MSP_RESULT_ERROR. But it
reports that as an ERROR RETURN, after the editor was built and the pilot had
already pressed Save -- and fwifGetEepromAddress() at :703-729 reports every
BLHeli-family target as ESC_SIG_BLHELI_S with length 0x70, so for BLHeli_S
against Bluejay signature, version and length are identical and the editor gate
is the only one there is.

No build and no package step reaches any of it, so the three pages and the shared
editor are driven for real here, each answered with another vendor's own reply
fixture. Case 4 is the other half and matters as much: the matching page has to
open and its Save has to put an MSP 218 on the bus, or case 6's "never sent" is
also true of a harness whose write path was never live. Not hypothetical -- the
first version of this harness stubbed page_runtime, never pressed Save, and had
six write checks that stayed green with the gate removed. Its own --self-test is
what said so.

Pass --self-test to prove the rest: it re-runs every case against a copy of
esc_forward_vendor.lua whose isCompatibleEsc() returns true unconditionally and
requires all 30 gate checks to fail.
'''
    ),
    LuaJob(
        id='esc-parameters-yge',
        name='YGE timing words and the flags byte',
        step='Check the YGE forward-programming codec',
        script='bin/esc_parameters_yge/verify_esc_parameters_yge.lua',
        rationale=r'''lib/msp_esc_parameters_yge.lua drew its Motor Timing row from a ten-entry list of UI
positions and handed that position to the wire unchanged in both directions. The
ESC does not number its timing the way the page does: it spells the four automatic
modes 16..19 and the six fixed advance angles 1..6, with 0 a second spelling of the
first automatic mode. So every word the ESC sent landed on the wrong row, and every
row the pilot picked landed on the wrong word -- measured: an ESC reporting 17 ("Auto
Efficient") displayed "Auto Norm", and a pilot selecting "0 deg" wrote 17, a fixed
advance angle commanded as an automatic mode. Neither is visible from the page,
which shows a position in its own list rather than the ESC's word.

The flight controller is a pass-through here -- msp.c reads
escGetParamBufferLength() bytes and calls escCommitParameters() without inspecting a
field -- so no build and no package step can see any of it. The harness drives the
real page, the real shared editor, the real field_layout and the real page_runtime,
and answers reads with the codec's own simulatorResponse.

21 of its 38 checks go red on the pre-fix codec. Pass --self-test to prove that
rather than take it on trust: it re-runs the file against a copy of the codec with
the pre-fix TIMING table, no translation block and the pre-fix decode()/encode(),
and requires every one of those 21 to fail. It also requires both passes to have
registered the same gates, so a case that runs on one of the two trees and not the
other is reported rather than silently compared against nothing.

The file also answers the issue's other half, which does NOT reproduce: the reserved
bits 4..7 of the flags byte survive a save here, because this page keeps the ESC's
byte and edits single bits in place (field_layout.lua:268-272) rather than packing
four booleans into a fresh byte the way the EdgeTX page does (edgetx
.../yge/page.lua:113-131). Five checks pin that, plus the load gate. They are
deliberately not gates: they pass on the pre-fix codec too, and a gate check that
cannot go red is worse than no check.
'''
    ),
    LuaJob(
        id='esc-raw-bytes',
        name='An ESC save rewrites only the row the pilot moved',
        step='Check that unedited ESC bytes survive a save',
        script='bin/esc_raw_bytes/verify_esc_raw_bytes.lua',
        rationale=r'''Both ESC forward-programming codecs laid the write payload out from the parsed fields
alone. lib/msp_esc_parameters_bluejay.lua and lib/msp_esc_parameters_am32.lua
both walked WIRE_FIELDS and wrote one byte per entry from `data[name]`; Bluejay's
decode() already kept the ESC's own bytes in `data._raw` and nothing read them.

That is not a display bug, because the flight controller merges nothing.
msp.c's MSP_SET_ESC_PARAMETERS (msp.c:3397-3409) copies exactly
escGetParamBufferLength() bytes over the update buffer and commits that, and that
length is a two-byte header plus BLHELI_S_MSP_NUM_EEPROM_BYTES (0x40) for the 0xC1
signature Bluejay shares with BLHeli_S, or AM32_NUM_EEPROM_BYTES (0x30) for 0xC2
(esc_sensor.c:4553-4570). So Bluejay is 66 bytes and AM32 is 50 -- and the ESC
parameter bytes beyond that window are the firmware's own business, kept from its
own cache in fourwayIfFetchData (esc_sensor.c:765-819). These first 0x40 bytes are
the Lua suite's and nobody else's. Every byte encode() did not reproduce
byte-for-byte is a byte the ESC is told changed.

Measured on the pre-fix codecs, poking one byte at a time over all 256 values and
re-encoding with nothing edited: Bluejay rewrote 130 of the 256 minimum-startup-
power bytes, 181 of the maximum-startup-power bytes, one of the PWM-frequency
bytes and 155 and 188 of the two PWM-threshold bytes -- 655 in all -- and AM32
rewrote 248 of the 256 timing-advance bytes, because two firmware generations
number the same four positions differently (0..3 and 10..42 in steps of 8) and
both spellings occur in the field. The pre-fix Bluejay encoder also clamped
threshold_96to48 onto threshold_48to24 on every save, so an ESC reporting the
pair the other way round was corrected whether or not the pilot looked at either
row.

encode() now starts from a copy of the ESC's own bytes and writes one field only
when the pilot moved it off the byte that value came from. It is the rule the
EdgeTX suite already applies to its five transformed Bluejay fields
(esc_parameters_bluejay.lua's TRANSFORMS / buildWritePayload) and to the AM32
timing byte (encodeTimingAdvance), extended from those fields to the whole block.
A write with no ESC bytes behind it is now a REFUSED write rather than a payload
of zeros, the same shape as lib/msp_governor_profile.lua's refusal and handled by
app/page_runtime.lua's existing nil-message branch.

The exhaustive check is the one that matters and it is not a sample: every byte
position against every one of its 256 values, decode/encode with nothing edited.
That is 16896 Bluejay pairs and 12800 AM32 ones, and on the pre-fix codecs it fails
at exactly the six positions above. The staged page-level cases exist because
every value in the shipped fixtures happens to survive the pre-fix round trip, so
a case built on the fixture alone would have passed on the defective codec.

No build and no package step reaches any of it: it needs two codecs, a page, a
shared editor, a runtime and an MSP round trip. The harness drives the real pages
and the real runtime, and stubs app/pages/esc_forward_4way.lua for the reason
bin/esc_signature does -- it only picks which ESC to address, and its own
os.clock() delays cost about six seconds per open.

14 of its 41 checks go red on the pre-fix codecs. Pass --self-test to prove that
rather than take it on trust: it splices the pre-fix codec directions and the
pre-fix buildWriteMessage back into copies of both codecs and requires every one
of the fourteen to fail. Three things in that self-test were wrong the first time
and are recorded here because each of them made the self-test pass without proving
anything:
  * the spliced codecs were loaded through the normal helper, which reads the
    checked-out path and never sees the redirect -- so nine of the seventeen gates
    then registered stayed green on the FIXED codec;
  * two gates carried identical wording from the two codecs' refusal checks and
    collided in the gate list, which the duplicate counter caught;
  * the first discriminator for "is this the pre-fix codec?" asked whether byte 7
    moved, which proves nothing: 0 is a legal minimum-startup-power byte and
    normalizes straight back to 0.
And the eight timing-decode cases, the three timing write-direction cases and the
Motor KV case are deliberately NOT gates -- they pass on the pre-fix codec too,
and a gate check that cannot go red is worse than no check.
'''
    ),
    # Appended after #2456 was opened, so this entry is a pure addition rather
    # than a re-registration of esc-parameters-yge: that job arrived with #2456.
    LuaJob(
        id='esc-parameters-yge-bec12v',
        name='YGE 12 V BEC ceiling and the HV-BEC bit',
        step='Check the 12 V BEC ceiling and the flag',
        script='bin/esc_parameters_yge/verify_yge_bec12v.lua',
        rationale=r'''Seven of the twenty-one YGE models have an HV BEC that runs up to 12.0 V, and the BEC
Voltage field was capped at 8.4 V for all of them -- because the ceiling is a
property of the MODEL and the field took its range from a constant in FIELD_META.
app/field_layout.lua's buildField() has always honoured spec.min/spec.max, and
app/pages/esc_forward_vendor.lua's fieldSpec() read them from FIELD_META only, so
a page had no way to say otherwise. It now resolves them the way it already
resolved labels: a value, or a function of the read data.

The second half is the flags byte. Its HV-BEC bit (bit 3) has no row on this
page -- bits 0 and 1 have rows, bit 3 did not -- so selecting 12.0 V commanded the
voltage without the mode that makes it 12 V. The codec sets it from
page_runtime's beforeSave hook, the same place and shape
msp_esc_parameters_scorpion.lua already uses.

Two rules, and the second is the one a reviewer should check: when the pilot MOVED
the voltage the bit becomes (voltage == 120), and when they did not the bit is
left exactly as the ESC reported it. An ESC reporting 8.4 V with the bit set is in
a state this page never produced, and a save that changed the governor gain has no
business clearing a BEC setting nobody looked at.

The harness found that second rule the hard way: the first version enforced the
invariant unconditionally and its own "an unrelated save leaves the bit alone" case
went red. It is now the same rule the timing translation in #2456 follows.

Finding on the way: the model table was missing [4691] "YGE Saphir 125v2" -- one
of the seven 12 V models, and the first one #2337 names. It rendered as
"YGE ESC (4691)", and with no entry there was nothing to raise the ceiling for.
The EdgeTX table's own comment says why: name and capability used to be two lists,
"and adding a model meant remembering both -- which is how 4691 came to be in
neither". So this is ONE table carrying both facts, not a second list beside the
first.

Two entries in the EdgeTX table are worth reading before "correcting" them: [5712]
"YGE 165 HVT" and [8272] "YGE 205 HVT" carry neither BEC nor Opto nor v2 in the
name and still run to 12.0 V. So "12 V means v2" is not the rule -- it holds for
four of the seven, which is what that table happens to contain. This suite asserts
parity with it on all 21 entries, and separately that [8272] keeps the owner's v2
spelling (2026-10-03). The one field EdgeTX has no notion of is `bec`: only the
five Opto models lack one, so their BEC Voltage row is hidden rather than capped.
11 of its 28 checks go red without the fix. Pass --self-test to prove that: it cuts
the fix back out of the three files that carry it and requires every one of the
eleven to fail -- and verifies its own cut four ways first, because a slice that
takes an unrelated table with it looks exactly like a test failure.
'''
    ),
    LuaJob(
        id='tune-history',
        name='Tune Advisor history on disarm',
        step='Check the Tune Advisor history on disarm',
        script='bin/tune_history/verify_tune_history.lua',
        rationale=r'''The FC keeps its tune advisor statistics in RAM; the radio saves each
flight on disarm, clears the FC, and the page combines the last 5 flights
on the current tune. Pins the capture (one flight per disarm, then a
clear; 5 flights kept; a disarm during a link loss captured on reconnect;
firmware without the command asked once) and the aggregate (only the
newest tune, counts added, ratios weighted).
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
