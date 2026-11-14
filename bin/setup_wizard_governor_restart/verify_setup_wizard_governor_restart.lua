-- Behaviour check for #2696: changing the governor mode in the Setup Wizard requests an FC restart.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_governor_restart/verify_setup_wizard_governor_restart.lua
--     lua5.4 bin/setup_wizard_governor_restart/verify_setup_wizard_governor_restart.lua --self-test
--
-- The flight controller reads gov_mode only once during boot (governorInit in fc/init.c).
-- Changing the governor mode in the wizard therefore requires an FC restart. Because Governor is
-- step 9 (before the Connect servos gate at step 11), wiz.requestReboot() ensures that the Connect
-- gate executes the restart before flight.
--
-- What it drives:
--   1. Real src/rfsuite/app/pages/setup_wizard_governor.lua with UI/art stubs;
--   2. Pins that entering the step or leaving the mode untouched requests no reboot;
--   3. Pins that changing mode (Off -> Electric, Electric -> Nitro, Electric -> Off) calls wiz.requestReboot();
--   4. Checks that setup_wizard.md and setup_wizard/governor.md document the restart requirement.
--
-- --self-test runs the check against a mutant where wiz.requestReboot() is removed from setMode().

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local MODULE = ROOT .. "/src/rfsuite/app/pages/setup_wizard_governor.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

-- ── stubs ─────────────────────────────────────────────────────────────

local scr
local function newScreen()
  local s = { title = nil, rows = nil, forward = nil, start = nil }
  function s.begin() s.rows, s.back, s.forward, s.start = nil, nil, nil, nil end
  function s.text(_, title) s.title = title end
  function s.step() end
  function s.picture() end
  function s.paint() end
  function s.refresh() end
  function s.checks(_, rows)
    s.rows = rows
    return {}
  end
  function s.row(_, back, _, forward)
    s.back, s.forward = back, forward
    return {}
  end
  function s.safety(_, _, _, _, startPress)
    s.start = startPress
    return {}
  end
  return setmetatable(s, { __index = function() return function() end end })
end

local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end

local FEATURE_GOVERNOR = 2 ^ 26

local function newWiz(initialMode)
  local mode = initialMode or 0
  local config = { gov_mode = mode, gov_throttle_type = 0 }
  local features = (mode > 0) and FEATURE_GOVERNOR or 0
  local rebootRequested = false

  local w = {
    governorMode = function()
      if (features & FEATURE_GOVERNOR) == 0 then return 0 end
      return config.gov_mode or 0
    end,
    governorConfig = function() return config end,
    requestReboot = function() rebootRequested = true end,
    rebootRequested = function() return rebootRequested end,
    clearReboot = function() rebootRequested = false end,
    editGovernor = function(fn)
      fn(config)
      mode = config.gov_mode
    end,
    setFeature = function(bit, on)
      if on then features = features | bit else features = features & ~bit end
    end,
    rebuild = function() end,
    send = function() end,
    change = function() end,
    forward = function(fn) return { text = "Next", press = fn } end,
  }
  return w
end

local stubs = {
  ["app/setup_wizard_ui.lua"] = { new = function() scr = newScreen(); return scr end },
  ["app/setup_wizard_art.lua"] = setmetatable({}, { __index = function() return function() return anyObject() end end }),
  ["lib/msp_governor_profile.lua"] = {
    buildReadMessage = function() return {} end,
    buildWriteMessage = function() return {} end,
  },
  ["lib/msp_select_profile.lua"] = {
    buildWriteMessage = function() return {} end,
  },
  ["lib/msp_status.lua"] = {
    buildReadMessage = function() return {} end,
  },
}

package.loaded["rfsuite.lib.require"] = function(path)
  local s = stubs[path]
  if not s then error("unexpected require: " .. tostring(path)) end
  return s
end

-- ── drive the step ────────────────────────────────────────────────────

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local function runGovernorStep(source, initialMode)
  local before = failures
  local wiz = newWiz(initialMode)
  local chunk = assert(load(source, "@setup_wizard_governor.lua", "t"))
  local factory = chunk()
  local step = factory.new(wiz)

  -- 1. Entry into prepare screen
  step.build()
  check("step starts on prepare screen with Start button", scr.start ~= nil)
  check("entry requests no reboot", wiz.rebootRequested() == false)
  if not scr.start then return failures - before end

  -- 2. Move to mode screen
  scr.start()
  step.build()
  check("mode screen creates rows", scr.rows ~= nil and #scr.rows >= 1)
  check("moving to mode screen requests no reboot", wiz.rebootRequested() == false)

  local modeChoice = scr.rows and scr.rows[1] and scr.rows[1].choice
  check("first row has a mode choice", modeChoice ~= nil and modeChoice.set ~= nil)
  if not (modeChoice and modeChoice.set) then return failures - before end

  -- 3. Setting the same mode requests no reboot
  modeChoice.set(initialMode)
  check("selecting the same mode requests no reboot", wiz.rebootRequested() == false)

  -- 4. Switching to Electric (mode 3)
  local targetMode = (initialMode == 3) and 0 or 3
  modeChoice.set(targetMode)
  check("changing governor mode requests an FC reboot", wiz.rebootRequested() == true,
    "mode " .. tostring(initialMode) .. " -> " .. tostring(targetMode) .. " did not call wiz.requestReboot()")
  check("governor mode was updated", wiz.governorMode() == targetMode)

  -- 5. Setting the same new mode requests no additional reboot
  wiz.clearReboot()
  modeChoice.set(targetMode)
  check("selecting the newly set mode again requests no reboot", wiz.rebootRequested() == false)

  -- 6. Switching to Nitro (mode 4)
  if targetMode ~= 4 then
    wiz.clearReboot()
    modeChoice.set(4)
    check("switching to Nitro requests an FC reboot", wiz.rebootRequested() == true)
    check("governor mode is now Nitro (4)", wiz.governorMode() == 4)
  end

  -- 7. Switching back to Off (mode 0)
  wiz.clearReboot()
  modeChoice.set(0)
  check("switching back to Off requests an FC reboot", wiz.rebootRequested() == true)
  check("governor mode is now Off (0)", wiz.governorMode() == 0)

  return failures - before
end

local function runDocs()
  local before = failures
  local overview = readFile(ROOT .. "/docs/pages/wizards/setup_wizard.md")
  check("setup_wizard.md mentions governor mode in reboot notes",
    overview:find("governor mode", 1, true) ~= nil,
    "expected 'governor mode' in setup_wizard.md restart points")

  local govDoc = readFile(ROOT .. "/docs/pages/wizards/setup_wizard/governor.md")
  check("governor.md documents the restart on mode change",
    govDoc:find("Changing the governor mode requests a restart", 1, true) ~= nil,
    "expected restart note in governor.md")

  return failures - before
end

local source = readFile(MODULE)

if not SELF_TEST then
  local n = runGovernorStep(source, 0) + runGovernorStep(source, 3) + runDocs()
  if n == 0 then
    print("OK  Setup Wizard governor mode change requests an FC restart (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

-- ── self-test ─────────────────────────────────────────────────────────

local mutant, count = source:gsub("wiz%.requestReboot%(%)", "-- mutant: no reboot requested")
if count ~= 1 then
  print("FAIL  self-test: could not splice wiz.requestReboot() in setup_wizard_governor.lua")
  os.exit(1)
end

failures, checks = 0, 0
local caught = runGovernorStep(mutant, 0)
if caught > 0 then
  print("ok    mutant red: no reboot requested on mode change (" .. caught .. " failed checks)")
  print("OK  self-test: removing wiz.requestReboot() goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: removing wiz.requestReboot() did not go red")
os.exit(1)
