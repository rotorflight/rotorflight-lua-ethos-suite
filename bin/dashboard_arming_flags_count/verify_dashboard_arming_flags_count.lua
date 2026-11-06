-- Behaviour check for issue #2668: the dashboard info panel names the arming-disable flags by the
-- layout of the firmware it is connected to.
--
-- Run it:
--     lua5.4 bin/dashboard_arming_flags_count/verify_dashboard_arming_flags_count.lua
--
-- What it drives, and why:
--   * The real widgets/dashboard.lua, loaded and registered as the radio does (the Ethos stubs of
--     bin/bar_disconnect). Its info panel's controller rows are built by the local function
--     refreshControllerRows; the harness takes that function from the widget's own closures by
--     name and calls it with a widget state, so the panel code itself runs, not a copy.
--   * From MSP API 12.09 (firmware 4.6) bit 25 is OVERRIDE and bit 26 ARMSWITCH; before that bit
--     25 is ARMSWITCH (lib/arming_flags.lua, countForApi and tagFor). The widget's API version
--     comes from the session snapshot (tasks/session.lua apiVersionMajor/apiVersionMinor).
--   * Against unpatched master the panel decodes without the count: on 12.09 an active override
--     reads as the arm switch, and the arm-switch bit shows as 0x4000000.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/rfsuite"

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then
    f:close()
    return name
  end
  return SUITE .. "/" .. name
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then
    path = resolvePath(path)
  end
  if env ~= nil then
    return realLoadfile(path, mode, env)
  elseif mode ~= nil then
    return realLoadfile(path, mode)
  else
    return realLoadfile(path)
  end
end

-- rfsuite.lib.require is loadfile() against Ethos' path prefixes on a radio.
local function requireModule(name)
  local key = "rfsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(resolvePath(name))
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["rfsuite.lib.require"] = requireModule

-- ---------------------------------------------------------------------------
-- Ethos stubs
-- ---------------------------------------------------------------------------

FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L = 1, 2, 3, 4, 5
CENTERED, TEXT_LEFT = 16, 0
EVT_KEY, EVT_TOUCH = 10, 11
TOUCH_START, TOUCH_MOVE, TOUCH_END = 20, 21, 22
KEY_PAGE_LONG, KEY_ENTER_BREAK, KEY_EXIT_BREAK, KEY_RTN_BREAK, KEY_DOWN_BREAK = 30, 31, 32, 33, 34
ROTARY_LEFT, KEY_ROTARY_RIGHT = 40, 41

lcd = setmetatable({
  RGB = function(_, _, _, alpha) return {alpha = alpha or 1} end,
  color = function() end,
  drawFilledRectangle = function() end,
  drawText = function() end,
  font = function() end,
  getTextSize = function(text) return #tostring(text) * 7, 14 end,
  getWindowSize = function() return 480, 320 end,
  hasFocus = function() return true end,
  isVisible = function() return true end,
  invalidate = function() end,
}, {__index = function() return function() end end})

os.stat = function() return nil end
system = {
  registerWidget = function(w) _G.__widget = w end,
  killEvents = function() end,
  openPage = function() end,
  getMemoryUsage = function() return {mainStackAvailable = 4096} end,
  getVersion = function() return {simulation = false} end,
  voltageRange = function() return 7.2, 8.4 end,
  getSource = function() return nil end,
}
model = {bitmap = function() return nil end}

-- Every form.openDialog is recorded, so a confirm button can be pressed by the
-- check the way a pilot presses OK.
local dialogs = {}
form = setmetatable({
  openDialog = function(opts)
    if type(opts) == "table" then dialogs[#dialogs + 1] = opts end
  end,
  openProgressDialog = function()
    return {value = function() end, closeAllowed = function() end, close = function() end}
  end,
}, {__index = function() return function() end end})

local failures, checks = 0, 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
  return ok
end

-- ---------------------------------------------------------------------------
-- The panel's own function, from the widget's closures
-- ---------------------------------------------------------------------------

local dashboard = requireModule("widgets/dashboard.lua")
dashboard.init({})
local descriptor = _G.__widget
check("the dashboard widget registered itself", descriptor ~= nil)
if descriptor == nil then os.exit(1) end

local function findUpvalue(roots, name)
  local seen, queue = {}, {}
  for _, f in pairs(roots) do if type(f) == "function" then queue[#queue + 1] = f end end
  while #queue > 0 do
    local f = table.remove(queue, 1)
    if not seen[f] then
      seen[f] = true
      local i = 1
      while true do
        local n, v = debug.getupvalue(f, i)
        if not n then break end
        if n == name and type(v) == "function" then return v end
        if type(v) == "function" then queue[#queue + 1] = v end
        i = i + 1
      end
    end
  end
end

local refreshControllerRows = findUpvalue(descriptor, "refreshControllerRows")
check("the info panel's refreshControllerRows is reachable", refreshControllerRows ~= nil)
if not refreshControllerRows then os.exit(1) end

local TAG = function(n) return "@i18n(app.modules.fblstatus.arming_disable_flag_" .. n .. ")@" end
local OVERRIDE = TAG("override")

local function reasonsFor(major, minor, mask)
  local widget = {connected = true, mspTransport = "crsf", armDisableFlags = mask,
    apiVersionMajor = major, apiVersionMinor = minor}
  local rows, reasons = {}, {}
  refreshControllerRows(widget, rows, reasons)
  return reasons
end

local function list(t) return table.concat(t, ", ") end

-- Firmware 4.6, MSP API 12.09: 27 flags.
local r = reasonsFor(12, 9, 2 ^ 25)
check("12.09: bit 25 reads as OVERRIDE", #r == 1 and r[1] == OVERRIDE, list(r))
-- The arm switch is only set together with another reason, and the panel
-- leaves it out (docs/dashboard/controls.md, Info panel).
r = reasonsFor(12, 9, 2 ^ 26)
check("12.09: the arm switch alone gives no reason", #r == 0, list(r))
r = reasonsFor(12, 9, 2 ^ 25 + 2 ^ 26)
check("12.09: the override shows, the arm switch does not", #r == 1 and r[1] == OVERRIDE, list(r))
r = reasonsFor(12, 9, 2 ^ 7 + 2 ^ 26)
check("12.09: another reason shows, the arm switch does not", #r == 1 and r[1] == TAG(7), list(r))

-- Firmware 4.5, MSP API 12.08: 26 flags, bit 25 is the arm switch.
r = reasonsFor(12, 8, 2 ^ 25)
check("12.08: the arm switch alone gives no reason", #r == 0, list(r))
r = reasonsFor(12, 8, 2 ^ 1 + 2 ^ 25)
check("12.08: another reason shows, the arm switch does not", #r == 1 and r[1] == TAG(1), list(r))

-- No flag set: the panel says ready.
r = reasonsFor(12, 9, 0)
check("12.09: no flag gives no reason", #r == 0, list(r))

if failures > 0 then
  print(string.format("\n%d of %d checks failed", failures, checks))
  os.exit(1)
end
print(string.format("\n%d checks passed", checks))
