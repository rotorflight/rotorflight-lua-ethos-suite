--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html

  Entry point. This file is intentionally thin: it loads and initialises
  three completely independent subsystems and does nothing else. There is
  no shared `rfsuite` table, no `package.loaded.rfsuite` global, and this
  file never touches the internals of app/, widgets/, or tasks/.

    app/     - the system tool      (system.registerSystemTool)
    widgets/ - dashboard/ActiveLook (system.registerWidget/registerGlassesWidget)
    tasks/   - the background task  (system.registerTask)

  Each owns its own private state via closures. The only thing they are
  allowed to share is lib/bus.lua, a minimal publish/subscribe channel --
  never direct table access.

  All three subsystems register direct callbacks eagerly. This costs more
  startup RAM than lazy proxies, but avoids retained-RAM growth observed on
  device with the lazy callback layer.
]] --

-- Measures wall time from the moment Ethos starts running this file to the
-- moment every subsystem's init() has returned -- i.e. the eager loadfile()
-- chain rooted at the three requires below (background.lua/tool.lua/
-- dashboard.lua each transitively loadfile() their own dependencies at
-- module-load time, before init() is even called) plus each subsystem's own
-- registration work. Answers "does the eager-load disk IO actually cost
-- anything perceptible" with a real number instead of a guess -- see the
-- eager-vs-lazy tradeoff noted below. Printed once, unconditionally: this
-- runs a single time per app lifetime, not per tick, so the cost of the
-- print itself is noise.
local bootStartAt = os.clock()

-- Per-component timing, reported alongside the overall total below. Each
-- entry is [label, seconds]; printed in the order recorded so the eager
-- loadfile() cost (module-load time) and the init() cost (registration
-- work) are visible separately per subsystem, not just as one combined
-- number.
local bootSteps = {}
local function mark(label, startedAt)
  bootSteps[#bootSteps + 1] = {label, os.clock() - startedAt}
end

-- Parsed by bin/package/build_package.py (MAIN_VERSION_RE/MAIN_SUFFIX_RE) to
-- derive the packaged manifest version; the suffix segment is rewritten
-- per-build. The literal name/shape of this table is load-bearing for that
-- regex. Keep this in sync with lib/build_info.lua's runtime-visible copy.
local version = {major = 2, minor = 3, revision = 1, suffix = ""}

local t0 = os.clock()
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local background_task = requireModule("tasks/background.lua")
mark("tasks/background.lua load", t0)

t0 = os.clock()
local system_tool = requireModule("app/tool.lua")
mark("app/tool.lua load", t0)

t0 = os.clock()
local dashboard_widget = requireModule("widgets/dashboard.lua")
mark("widgets/dashboard.lua load", t0)

local activelook_widget = nil

-- The incremental collector's pause, as a percentage of the live heap. A
-- collection cycle starts once the heap has reached live * pause / 100, so the
-- default (200 in both 5.3 and 5.4) lets the heap grow to twice what is live
-- before anything is reclaimed at all. Ethos kills a script whose Lua heap
-- passes its limit (#2295, "Lua has used too much RAM, it has been Killed"), so
-- a pause tuned for a general-purpose host starts collecting at a point the
-- radio has already given up by. 120 cuts the permitted excess from 100% of
-- live down to 20% of live.
--
-- THE VALUE IS A STARTING POINT, NOT A MEASURED ONE. Nothing in this
-- repository states Ethos's Lua heap limit, so there is no number here to
-- derive a pause from, and no on-device run yet measures what a lower pause
-- costs the background task's instruction budget (tasks/engine.lua). What makes
-- this worth trying anyway is that it is one line to change and one line to
-- revert -- see docs/memory-and-module-lifecycle.md section 9.4 for the
-- measurement that decides it, which needs no code at all.
--
-- setstepmul is deliberately NOT touched. It is the second knob and it trades
-- collector throughput against step size; there is no measurement showing
-- jitter that it would fix here, so changing it would be a guess in the other
-- direction.
local GC_PAUSE_PERCENT = 120

-- Applies GC_PAUSE_PERCENT and reports what was applied.
--
-- `collectgarbage("setpause", n)` returns the PREVIOUS value, and with the
-- argument omitted it does not read the current one -- it sets the pause to 0.
-- Pause 0 is "collect as constantly as possible", the opposite of what this is
-- for, and the Lua 5.3.6 in this checkout does exactly that
-- (bin/gc_pause/verify_gc_pause.lua pins it). So the applied value is kept here
-- and printed, never read back.
--
-- Guarded because "setpause" is a mode string like any other and a Lua without
-- it would otherwise abort the boot. A guard that fails says so: a silent one
-- would leave the log asserting a pause that was never applied.
local function applyGcPause()
  local ok, err = pcall(collectgarbage, "setpause", GC_PAUSE_PERCENT)
  if not ok then
    print(string.format("[boot] gc: setpause(%d) NOT applied on this Lua: %s",
      GC_PAUSE_PERCENT, tostring(err)))
    return false
  end
  print(string.format("[boot] gc: pause=%d%% of live heap before a cycle starts (Lua default 200)",
    GC_PAUSE_PERCENT))
  return true
end

local function init()
  t0 = os.clock()
  -- Before the three subsystems below, so the collector is already on its own
  -- schedule while they allocate. What this does NOT cover is the eager
  -- loadfile() chain at lines 53/57/61: that burst of parsing happens at
  -- module load, before init() runs, and what it leaves behind is the live code
  -- that no pause setting makes smaller. That is also why this is a creep
  -- measure and not a boot-peak measure.
  applyGcPause()
  mark("gc.setpause", t0)

  t0 = os.clock()
  background_task.init()
  mark("background_task.init", t0)

  t0 = os.clock()
  local systemToolHandle = system_tool.init()
  mark("system_tool.init", t0)

  t0 = os.clock()
  dashboard_widget.init({systemToolHandle = systemToolHandle})
  mark("dashboard_widget.init", t0)

  if system.registerGlassesWidget then
    t0 = os.clock()
    activelook_widget = requireModule("widgets/activelook.lua")
    activelook_widget.init()
    mark("activelook_widget load+init", t0)
  end

  for _, step in ipairs(bootSteps) do
    print(string.format("[boot] %s: %.3fs", step[1], step[2]))
  end
  print(string.format("[boot] main.lua load+init: %.3fs", os.clock() - bootStartAt))
end

return {init = init}
