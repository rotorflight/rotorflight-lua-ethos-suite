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
local background_task = assert(loadfile("tasks/background.lua"))()
mark("tasks/background.lua load", t0)

t0 = os.clock()
local system_tool = assert(loadfile("app/tool.lua"))()
mark("app/tool.lua load", t0)

t0 = os.clock()
local dashboard_widget = assert(loadfile("widgets/dashboard.lua"))()
mark("widgets/dashboard.lua load", t0)

local activelook_widget = nil

local function init()
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
    activelook_widget = assert(loadfile("widgets/activelook.lua"))()
    activelook_widget.init()
    mark("activelook_widget load+init", t0)
  end

  for _, step in ipairs(bootSteps) do
    print(string.format("[boot] %s: %.3fs", step[1], step[2]))
  end
  print(string.format("[boot] main.lua load+init: %.3fs", os.clock() - bootStartAt))
end

return {init = init}
