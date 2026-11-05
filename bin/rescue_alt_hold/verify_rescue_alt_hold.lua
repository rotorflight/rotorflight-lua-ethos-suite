-- Behaviour check for issue #2688: setting the Setup Wizard's rescue step to On keeps a stored
-- altitude-hold mode (ALT_HOLD, 2) instead of overwriting it with climb (1), and shows ALT_HOLD
-- as On.
--
-- Run it (from the repository root):
--     lua5.4 bin/rescue_alt_hold/verify_rescue_alt_hold.lua
--     lua5.4 bin/rescue_alt_hold/verify_rescue_alt_hold.lua --self-test
--
-- What it drives: the real src/rfsuite/app/pages/setup_wizard_rescue.lua, with the UI, art and MSP
-- modules replaced by stubs and a simulated flight controller that keeps one rescue profile per PID
-- profile (the same rig as bin/setup_wizard_rescue_profiles). The firmware's rescue modes are
-- OFF 0, CLIMB 1, ALT_HOLD 2 (rotorflight-firmware settings.c, lookupTableRescueMode). It pins:
--   1. ALT_HOLD on every profile: the step shows On, and On writes ALT_HOLD back to every profile;
--   2. Off, then On, from ALT_HOLD: Off writes 0, and the On after it writes CLIMB, since no
--      altitude hold is stored any more;
--   3. CLIMB on every profile: On keeps CLIMB.
--
-- --self-test runs the same checks on a copy without the line that keeps ALT_HOLD and requires
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

-- The flight controller: one rescue profile per PID profile, each holding `mode`.
local function newFc(count, active, mode)
  local fc = {count = count, selected = active, original = active, profiles = {}, read = {}, written = {},
    selectedEver = {}}
  for i = 0, count - 1 do fc.profiles[i] = {rescue_mode = mode, rescue_flip_mode = 0} end
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

local function modes(fc)
  local out = {}
  for i = 0, fc.count - 1 do out[#out + 1] = tostring(fc.profiles[i].rescue_mode) end
  return table.concat(out, ",")
end

local function run(source)
  local before = failures

  -- 1. ALT_HOLD stored on every profile.
  local fc = newFc(3, 0, 2)
  local _, enable = open(source, fc)
  check("1a. the step offers the rescue switch", enable ~= nil)
  if enable then
    check("1b. a stored ALT_HOLD shows as On", enable.choice.get() == 1, "shown=" .. tostring(enable.choice.get()))
    enable.choice.set(1)
    check("1c. On keeps ALT_HOLD on every profile", modes(fc) == "2,2,2", "modes=" .. modes(fc))
  end

  -- 2. From ALT_HOLD: Off, then On.
  fc = newFc(3, 0, 2)
  _, enable = open(source, fc)
  if enable then
    enable.choice.set(0)
    check("2a. Off writes OFF to every profile", modes(fc) == "0,0,0", "modes=" .. modes(fc))
    check("2b. Off shows as Off", enable.choice.get() == 0, "shown=" .. tostring(enable.choice.get()))
    enable.choice.set(1)
    check("2c. On after Off writes CLIMB: no altitude hold is stored any more", modes(fc) == "1,1,1",
      "modes=" .. modes(fc))
  end

  -- 3. CLIMB stored on every profile.
  fc = newFc(3, 0, 1)
  _, enable = open(source, fc)
  if enable then
    check("3a. a stored CLIMB shows as On", enable.choice.get() == 1, "shown=" .. tostring(enable.choice.get()))
    enable.choice.set(1)
    check("3b. On keeps CLIMB", modes(fc) == "1,1,1", "modes=" .. modes(fc))
  end

  return failures - before
end

local source = readFile(STEP)

if not SELF_TEST then
  local n = run(source)
  if n == 0 then
    print("OK  rescue: On keeps a stored altitude hold, and ALT_HOLD shows as On (" .. checks .. " checks)")
    os.exit(0)
  end
  os.exit(1)
end

local mutated, n = source:gsub("\n[^\n]*if m == 1 and %(current%(%)%.rescue_mode or 0%) == 2 then m = 2 end", "")
if n ~= 1 then
  print("FAIL  self-test: the line that keeps ALT_HOLD was not found once; update this harness")
  os.exit(1)
end
failures, checks = 0, 0
local caught = run(mutated)
if caught > 0 then
  print("ok    mutant red: On without keeping ALT_HOLD (" .. caught .. " failed checks)")
  print("OK  self-test: overwriting ALT_HOLD with CLIMB goes red")
  os.exit(0)
end
print("FAIL  mutant passed the checks: On without keeping ALT_HOLD")
os.exit(1)
