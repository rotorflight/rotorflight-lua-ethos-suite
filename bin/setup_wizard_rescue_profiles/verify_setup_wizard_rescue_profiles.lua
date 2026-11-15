-- Behaviour check for #2689: the Setup Wizard's rescue step reads and writes rescue on every PID profile
-- the board has (up to the firmware's six), shows the active profile's value, and selects the active
-- profile again afterwards.
--
-- Run it (from the repository root):
--     lua5.4 bin/setup_wizard_rescue_profiles/verify_setup_wizard_rescue_profiles.lua
--     lua5.4 bin/setup_wizard_rescue_profiles/verify_setup_wizard_rescue_profiles.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_rescue.lua, with the UI, art and MSP
-- modules replaced by stubs and a simulated flight controller that keeps one rescue profile per PID
-- profile and answers profile selection. It pins:
--   1. six profiles, profile 5 active: all six are read, the step shows profile 5's value, a change is
--      written to all six, and profile 5 is selected again;
--   2. three profiles: nothing above profile 3 is selected, read or written.
--
-- --self-test runs the same checks on a copy capped at three profiles (the old limit) and requires
-- check 1 to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end
local ROOT = scriptDir() .. "/../.."
local STEP = ROOT .. "/src/rfsuite/app/pages/setup_wizard_rescue.lua"

local SELF_TEST = false
for _, a in ipairs(arg or {}) do if a == "--self-test" then SELF_TEST = true end end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if not ok then
    failures = failures + 1
    print("FAIL  " .. label .. (detail and ("  -- " .. detail) or ""))
  end
end

local ENABLE_LABEL = "@i18n(app.modules.rescue.mode_enable)@"
local RESCUE_BOX = 53

local function copy(t)
  local r = {}
  for k, v in pairs(t or {}) do r[k] = v end
  return r
end

local function anyObject()
  return setmetatable({}, { __index = function() return function() end end })
end

-- The flight controller: one rescue profile per PID profile; only profile `active` has rescue on.
local function newFc(count, active)
  local fc = {count = count, selected = active, original = active, profiles = {}, read = {}, written = {},
    selectedEver = {}}
  for i = 0, count - 1 do fc.profiles[i] = {rescue_mode = (i == active) and 1 or 0, rescue_flip_mode = 0} end
  return fc
end

local function stubs(fc)
  return {
    ["app/setup_wizard_ui.lua"] = {new = function()
      local s = {}
      function s.begin() rawset(s, "rows", nil) end
      function s.checks(_, rows) rawset(s, "rows", rows); return {} end
      fc.screen = s
      return setmetatable(s, {__index = function() return function() return {} end end})
    end},
    ["app/setup_wizard_art.lua"] = setmetatable({}, {__index = function() return function() return anyObject() end end}),
    ["lib/msp_select_profile.lua"] = {buildWriteMessage = function(index, ok, err)
      return {kind = "select", index = index, ok = ok, err = err}
    end},
    ["lib/msp_rescue_profile.lua"] = {
      buildReadMessage = function(ok, err) return {kind = "rescue_read", ok = ok, err = err} end,
      buildWriteMessage = function(data, ok, err) return {kind = "rescue_write", data = data, ok = ok, err = err} end,
    },
    ["lib/msp_status.lua"] = {buildReadMessage = function(ok, err) return {kind = "status", ok = ok, err = err} end},
    ["lib/msp_modes.lua"] = {buildModeRangesReadMessage = function(ok, err)
      return {kind = "modes", ok = ok, err = err}
    end},
  }
end

local function newWiz(fc)
  local wiz = {}
  function wiz.send(msg)
    if msg.kind == "select" then
      if msg.index >= fc.count then if msg.err then msg.err() end return end
      fc.selected = msg.index
      fc.selectedEver[msg.index] = true
      if msg.ok then msg.ok() end
    elseif msg.kind == "status" then
      msg.ok({current_pid_profile_index = fc.original, pid_profile_count = fc.count})
    elseif msg.kind == "modes" then
      msg.ok({{id = RESCUE_BOX, range = {start = 900, ["end"] = 1100}}})
    elseif msg.kind == "rescue_read" then
      fc.read[fc.selected] = true
      msg.ok(copy(fc.profiles[fc.selected]))
    elseif msg.kind == "rescue_write" then
      fc.written[fc.selected] = true
      fc.profiles[fc.selected] = copy(msg.data)
      msg.ok()
    end
  end
  function wiz.change() end
  function wiz.rebuild() end
  return setmetatable(wiz, {__index = function() return function() end end})
end

local function readFile(path)
  local f = assert(io.open(path, "rb"), "cannot open " .. path .. " (run from the repository root)")
  local s = f:read("a")
  f:close()
  return (s:gsub("\r\n", "\n"))
end

local function keys(t)
  local out = {}
  for k in pairs(t) do out[#out + 1] = k end
  table.sort(out)
  return table.concat(out, ",")
end

local function open(source, fc)
  local s = stubs(fc)
  package.loaded["rfsuite.lib.require"] = function(path)
    local m = s[path]
    if not m then error("unexpected require: " .. tostring(path)) end
    return m
  end
  local step = assert(load(source, "@setup_wizard_rescue.lua", "t"))()
  local node = step.new(newWiz(fc))
  node.build()                       -- loads at once: the stubs answer synchronously
  node.build()
  local enable
  for _, r in ipairs(rawget(fc.screen, "rows") or {}) do if r.label == ENABLE_LABEL then enable = r end end
  return node, enable
end

local function run(source)
  local before = failures

  -- 1. Six profiles, profile 5 (index 4) active.
  local fc6 = newFc(6, 4)
  local _, enable6 = open(source, fc6)
  check("1a. all six profiles are read", keys(fc6.read) == "0,1,2,3,4,5", "read=" .. keys(fc6.read))
  check("1b. the step shows the active profile's value (profile 5)", enable6 ~= nil and enable6.choice.get() == 1,
    "shown=" .. tostring(enable6 and enable6.choice.get()))
  check("1c. profile 5 is selected again after the read", fc6.selected == 4, "selected=" .. tostring(fc6.selected))
  if enable6 then
    enable6.choice.set(0)
    check("1d. a change is written to all six profiles", keys(fc6.written) == "0,1,2,3,4,5",
      "written=" .. keys(fc6.written))
    local allOff = true
    for i = 0, 5 do if fc6.profiles[i].rescue_mode ~= 0 then allOff = false end end
    check("1e. every profile holds the new value", allOff)
    check("1f. profile 5 is selected again after the write", fc6.selected == 4, "selected=" .. tostring(fc6.selected))
  end

  -- 2. Three profiles, profile 1 active.
  local fc3 = newFc(3, 0)
  local _, enable3 = open(source, fc3)
  if enable3 then enable3.choice.set(1) end
  check("2a. three profiles: only 1 to 3 are read", keys(fc3.read) == "0,1,2", "read=" .. keys(fc3.read))
  check("2b. three profiles: only 1 to 3 are written", keys(fc3.written) == "0,1,2", "written=" .. keys(fc3.written))
  check("2c. three profiles: nothing above profile 3 is selected", keys(fc3.selectedEver) == "0,1,2",
    "selected=" .. keys(fc3.selectedEver))

  return failures - before
end

local source = readFile(STEP)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  rescue: every profile the board has is read and written, the active one shown and kept (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

local mutated, n = source:gsub("local MAX_PROFILES = 6\n", "local MAX_PROFILES = 3\n")
if n ~= 1 then
  print("FAIL  self-test: the MAX_PROFILES line was not found once; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = run(mutated)
if caught > 0 then
  print("ok    mutant red: capped at three profiles (" .. caught .. " failed checks)")
  print("OK  self-test: the old limit goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: capped at three profiles")
os.exit(1)
