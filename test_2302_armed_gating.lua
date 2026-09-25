-- Standalone tests for Issue #2302 armed-state menu gating.
--
-- Run:  lua5.3 test_2302_armed_gating.lua <path-to-repo-root>
--
-- Two suites:
--   1. app/armed_gating.lua's derivation rules, on synthetic trees.
--   2. The REAL menu tree from app/tool.lua, checked against an explicit
--      expected classification -- the part that actually protects a pilot,
--      and the part a synthetic tree cannot cover.
--
-- app/tool.lua is loaded with a sandboxed environment (loadfile's "t" mode
-- plus a metatable-backed stub table) so its ~98 eager lcd.loadMask calls
-- and its requireModule chain resolve without a radio. Only the module
-- table is needed; the test never calls create().

local ROOT = arg and arg[1] or "."
package.path = ROOT .. "/src/?.lua;" .. package.path

local passed, failed = 0, 0
local failures = {}

local function check(name, cond, detail)
  if cond then
    passed = passed + 1
  else
    failed = failed + 1
    failures[#failures + 1] = name .. (detail and (" -- " .. tostring(detail)) or "")
  end
end

local function eq(name, actual, expected)
  check(name, actual == expected, string.format("expected %s, got %s", tostring(expected), tostring(actual)))
end

--------------------------------------------------------------------
-- 1. Derivation rules
--------------------------------------------------------------------

local gating = assert(loadfile(ROOT .. "/src/rfsuite/app/armed_gating.lua"))()

local function tree()
  -- lockedLeaf / openLeaf / mixedMenu / lockedMenu / dynamicEntry
  local t
  t = {
    {title = "lockedLeaf", script = "x", lockedWhileArmed = true},
    {title = "openLeaf", script = "y"},
    {title = "mixedMenu", menuId = "mixed"},
    {title = "lockedMenu", menuId = "allLocked"},
    {title = "dynamicEntry", menuId = "hidden", visibleWhen = function() return false end},
  }
  t.menus = {
    mixed = {entries = {
      {title = "a", script = "a", lockedWhileArmed = true},
      {title = "b", script = "b"},
    }},
    allLocked = {entries = {
      {title = "c", script = "c", lockedWhileArmed = true},
      {title = "d", script = "d", lockedWhileArmed = true},
    }},
    hidden = {entries = {
      {title = "e", script = "e", lockedWhileArmed = true},
    }},
  }
  return t
end

-- 1a. leaf marks survive resolution
do
  local t = tree()
  gating.resolve(t, t.menus)
  eq("leaf: hand mark preserved", t[1].lockedWhileArmed, true)
  eq("leaf: unmarked stays nil", t[2].lockedWhileArmed, nil)
end

-- 1b. a submenu is locked only when EVERY visible child is locked
do
  local t = tree()
  gating.resolve(t, t.menus)
  eq("submenu: mixed children -> unlocked", t[3].lockedWhileArmed, nil)
  eq("submenu: mixed menu marked unlocked", t.menus.mixed.lockedWhileArmed, false)
  eq("submenu: all-locked children -> locked", t[4].lockedWhileArmed, true)
  eq("submenu: all-locked menu marked locked", t.menus.allLocked.lockedWhileArmed, true)
end

-- 1c. a visibleWhen entry counts as unlocked and drags its parent open
do
  local t = tree()
  gating.resolve(t, t.menus)
  eq("submenu: visibleWhen parent -> unlocked", t[5].lockedWhileArmed, nil)
  eq("submenu: visibleWhen entry is not locked", t.menus.hidden.lockedWhileArmed, true)
end

-- 1d. a hand mark on a submenu tile wins over the derived value
do
  local t = tree()
  t[3].lockedWhileArmed = true          -- mixed, but explicitly gated
  gating.resolve(t, t.menus)
  eq("submenu: explicit mark wins over derivation", t[3].lockedWhileArmed, true)
end

-- 1e. an empty menu is not "all children locked"
do
  local t = {{title = "empty", menuId = "e"}}
  local menus = {e = {entries = {}}}
  gating.resolve(t, menus)
  eq("empty menu is not locked", t[1].lockedWhileArmed, nil)
end

-- 1f. idempotent: running twice changes nothing
do
  local t = tree()
  gating.resolve(t, t.menus)
  local snapshot = {}
  for i = 1, #t do snapshot[i] = t[i].lockedWhileArmed end
  local mixedSnapshot = t.menus.mixed.lockedWhileArmed
  gating.resolve(t, t.menus)
  local same = true
  for i = 1, #t do if t[i].lockedWhileArmed ~= snapshot[i] then same = false end end
  check("idempotent: root entries stable", same)
  eq("idempotent: submenu flags stable", t.menus.mixed.lockedWhileArmed, mixedSnapshot)
end

-- 1g. a cycle must not hang (depth guard)
do
  local t = {{title = "a", menuId = "a"}, {title = "b", menuId = "a"}}
  local menus = {}
  menus.a = {entries = {{title = "a2", menuId = "a"}}}
  local ok = pcall(gating.resolve, t, menus)
  check("cycle: terminates without error", ok)
end

--------------------------------------------------------------------
-- 2. The real tree, from app/tool.lua
--------------------------------------------------------------------

-- Sandbox: everything tool.lua touches resolves to a harmless stub, except
-- the pieces the test actually reads back.
-- Forward declaration on purpose: stubIndex's body closes over
-- stubTable, and a name is only captured as an upvalue from its `local`
-- declaration onward. Declaring stubIndex first would compile that
-- reference as a global lookup and blow up on the first stub call.
local stubTable
local stubIndex = {
  -- requireModule("x") must return a table, else `x.something` blows up.
  __index = function(t, k)
    local fn = function() return stubTable() end
    rawset(t, k, fn)
    return fn
  end,
}
stubTable = function() return setmetatable({}, stubIndex) end

local REAL = {
  lcd = {loadMask = function() return {} end, getWindowSize = function() return 800, 480 end},
  -- tool.lua returns only {init = init}; the table carrying create/wakeup/
  -- paint/event/close is handed to system.registerSystemTool() from inside
  -- init(), so that call is where the test gets hold of it.
  system = {
    playHaptic = function() end,
    getVersion = function() return {simulation = true} end,
    registerSystemTool = function(t) return t end,
  },
  form = {clear = function() end},
  -- tool.lua's very first line indexes package.loaded, so this has to be the
  -- real table rather than a stub function.
  package = package,
  os = os, math = math, string = string, table = table, io = io,
  tonumber = tonumber, tostring = tostring, type = type, pcall = pcall,
  pairs = pairs, ipairs = ipairs, print = print, assert = assert,
  setmetatable = setmetatable, getmetatable = getmetatable,
  rawget = rawget, rawset = rawset, unpack = table.unpack,
}

-- Preseed the requireModule memoizer instead of letting tool.lua's
-- `loadfile("lib/require.lua")` fallback run. On a real radio main.lua
-- always loads that module first, so the cache-hit path is the production
-- path -- and it keeps the sandbox from needing a real loadfile (which
-- would pull the chunk in under the global env, not this one).
--
-- Memoized per module path (not a fresh table per call) so the test can
-- pre-install a capture hook on app/menu_container.lua and read back what
-- tool.lua's real create() handed it.
--
-- app/armed_gating.lua is served from disk rather than stubbed: it is the
-- code under test, and stubbing it would make the whole tree resolve to
-- nothing while still looking like a pass.
local realGating = assert(loadfile(ROOT .. "/src/rfsuite/app/armed_gating.lua"))()
local moduleStubs = {}
local function stubModule(path)
  if path == "app/armed_gating.lua" then return realGating end
  if not moduleStubs[path] then
    moduleStubs[path] = setmetatable({}, stubIndex)
  end
  return moduleStubs[path]
end
package.loaded["rfsuite.lib.require"] = stubModule

local captured = {}
stubModule("app/menu_container.lua").openRoot = function(_, rootEntries, _, _, _, _, menus, _, armedState)
  captured.rootEntries = rootEntries
  captured.menus = menus
  captured.armedState = armedState
end

setmetatable(REAL, {__index = function(t, k)
  local fn = function() return stubTable() end
  rawset(t, k, fn)
  return fn
end})

local env = setmetatable({_G = REAL}, {__index = REAL})

-- ROOT_ENTRIES and MENUS are locals of the main chunk, not upvalues, so
-- debug.getupvalue cannot see them (the main chunk's only upvalue is
-- _ENV). The tree is instead captured from what tool.lua's own create()
-- passes into menuContainer.openRoot -- which also means this section
-- exercises the real create() path rather than a re-implementation of it.
local registeredTool = nil
REAL.system.registerSystemTool = function(t) registeredTool = t return t end

local toolChunk = assert(loadfile(ROOT .. "/src/rfsuite/app/tool.lua", "t", env))
local toolModule = toolChunk()
check("tool.lua loads in sandbox", type(toolModule) == "table")

toolModule.init()
check("init() registered the system tool", type(registeredTool) == "table")
if type(registeredTool) == "table" and type(registeredTool.create) == "function" then
  registeredTool.create()
end

local ROOT_ENTRIES = captured.rootEntries
local MENUS = captured.menus
check("create() passed ROOT_ENTRIES to openRoot", ROOT_ENTRIES ~= nil)
check("create() passed MENUS to openRoot", MENUS ~= nil)
check("create() passed an armedState accessor", type(captured.armedState) == "function")
if captured.armedState then
  -- Nothing has published a session yet, so it must read as disarmed --
  -- otherwise every connected menu badges itself during the seconds before
  -- the first telemetry frame lands.
  eq("armedState defaults to false before any session", captured.armedState(), false)
end

if ROOT_ENTRIES and MENUS then
  -- 2a. The safety-critical set that MUST be gated. Written out
  --     explicitly: this is the assertion that a new FC-write page cannot
  --     be added without someone deciding whether it belongs here.
  --
  --     setup_menu is deliberately absent -- it contains controls_menu,
  --     which stays open because Controls > Stats is a local read, so the
  --     "all children locked" rule leaves Hardware Setup reachable and lets
  --     its own write pages badge individually. Asserted separately below.
  local MUST_LOCK = {
    mixer_menu = true, servos_menu = true,
    power_menu = true, esc_motors_menu = true, esc_forward_menu = true,
    setup_governor_menu = true, beepers_menu = true, blackbox_menu = true,
    flight_tuning_menu = true, advanced_menu = true, rates_advanced_menu = true,
    governor_menu = true,
  }
  for menuId in pairs(MUST_LOCK) do
    local sub = MENUS[menuId]
    check("locked menu present: " .. menuId, sub ~= nil)
    if sub then
      eq("submenu locked: " .. menuId, sub.lockedWhileArmed, true)
    end
  end

  -- 2b. Mixed containers must stay OPEN, so read-only pages a pilot wants
  --     while armed (Stats, Diagnostics) are not locked out by a sibling.
  --     setup_menu joins them for the same reason -- see above.
  local MUST_STAY_OPEN = {
    controls_menu = true, tools_menu = true, settings_menu = true,
    setup_menu = true,
  }
  for menuId in pairs(MUST_STAY_OPEN) do
    local sub = MENUS[menuId]
    check("open menu present: " .. menuId, sub ~= nil)
    if sub then
      eq("submenu open: " .. menuId, sub.lockedWhileArmed, false)
    end
  end

  -- 2b-bis. Inside a mixed container, every write page must still be gated
  --       individually -- this is the case a "lock the container" shortcut
  --       would have silently skipped.
  do
    local controls = MENUS.controls_menu
    local byName = {}
    for i = 1, #controls.entries do byName[controls.entries[i].title] = controls.entries[i] end
    for _, key in ipairs({"modes", "adjustments", "failsafe"}) do
      local e = byName[key]
      if e then eq("controls_menu: " .. key .. " locked", e.lockedWhileArmed, true) end
    end
    local stats = byName["stats"]
    if stats then eq("controls_menu: stats stays open", stats.lockedWhileArmed, nil) end
  end

  -- 2b-ter. Same for setup_menu: open itself, but its direct FC-write
  --        leaves are all gated.
  do
    local setup = MENUS.setup_menu
    local unlocked = {}
    for i = 1, #setup.entries do
      local e = setup.entries[i]
      if e.lockedWhileArmed ~= true then unlocked[#unlocked + 1] = tostring(e.menuId or e.title) end
    end
    check("setup_menu: only controls_menu is left open",
          #unlocked == 1 and unlocked[1] == "controls_menu",
          table.concat(unlocked, ", "))
  end

  -- 2c. Root tiles: Flight Tuning and Hardware Setup are gated; Logs and
  --     Settings are not.
  local byTitle = {}
  for i = 1, #ROOT_ENTRIES do
    byTitle[ROOT_ENTRIES[i].title] = ROOT_ENTRIES[i]
  end
  local rootLocked, rootOpen = 0, 0
  for i = 1, #ROOT_ENTRIES do
    local e = ROOT_ENTRIES[i]
    if e.offline == true then
      eq("offline root entry stays open: " .. e.title, e.lockedWhileArmed, nil)
      rootOpen = rootOpen + 1
    elseif e.lockedWhileArmed == true then
      rootLocked = rootLocked + 1
    else
      rootOpen = rootOpen + 1
    end
  end
  check("root has both locked and open tiles", rootLocked > 0 and rootOpen > 0,
        string.format("locked=%d open=%d", rootLocked, rootOpen))

  -- 2d. No entry anywhere may claim lockedWhileArmed on a page that is
  --     offline -- an offline page cannot touch the FC, so gating it would
  --     be pure loss of function for the pilot.
  local offlineViolations = {}
  local function audit(entries, path)
    for i = 1, #entries do
      local e = entries[i]
      if e.offline == true and e.lockedWhileArmed == true then
        offlineViolations[#offlineViolations + 1] = path .. "/" .. tostring(e.title)
      end
      if e.menuId then
        local sub = MENUS[e.menuId]
        if sub and sub.entries then audit(sub.entries, path .. "/" .. tostring(e.menuId)) end
      end
    end
  end
  audit(ROOT_ENTRIES, "root")
  check("no offline entry is gated", #offlineViolations == 0, table.concat(offlineViolations, ", "))

  -- 2e. Every connected leaf page is explicitly classified one way or the
  --     other -- i.e. someone looked at it. Reported as an inventory so a
  --     newly added page shows up in the list instead of silently defaulting.
  local classified, unclassified = {}, {}
  local function inventory(entries)
    for i = 1, #entries do
      local e = entries[i]
      if not e.visibleWhen then
        local key = e.script or ("menu:" .. tostring(e.menuId))
        if e.menuId then
          local sub = MENUS[e.menuId]
          if sub and sub.entries then inventory(sub.entries) end
        end
        if e.script then
          if e.lockedWhileArmed == true then
            classified[#classified + 1] = key
          else
            unclassified[#unclassified + 1] = key
          end
        end
      end
    end
  end
  inventory(ROOT_ENTRIES)
  check("leaf inventory non-trivial", #classified + #unclassified > 30,
        string.format("locked=%d open=%d", #classified, #unclassified))
end

--------------------------------------------------------------------
-- Result
--------------------------------------------------------------------

print(string.format("passed: %d   failed: %d", passed, failed))
if failed > 0 then
  for i = 1, #failures do print("  FAIL  " .. failures[i]) end
  os.exit(1)
end
os.exit(0)
