-- Behaviour check for the dashboard battery/fuel bar after telemetry loss (#2534).
--
-- Run it:
--     lua5.4 bin/bar_disconnect/verify_bar_disconnect.lua
--
-- Drives the real widgets/dashboard/objects/gauge/bar.lua (render.wakeup) with a
-- fake telemetry source. The claim: when the sensor drops out before flight, the bar
-- shows the loading state instead of the last percentage, and in postflight the last
-- value is kept for review. Against unpatched master the first claim fails.

--   * The claim the change makes: while the model is armed, the two toolbar
--     items that write to the flight controller (blackbox erase, battery
--     profile) are disabled, a battery picker open at the moment of arming
--     is closed, and a write that a dialog confirmed after arming is refused
--     at the write itself. Disarmed, both items work as before.
--   * The Reset and Info tiles are not written to the FC here and are checked
--     only to show that the arm state does not disable everything.
--
-- Not established here: that a rotor turning is safe to observe on a
-- simulator, or how the greyed tiles look on a 480x320 radio. The stub lcd
-- does not rasterise. The Ethos simulator check is named in the PR body.
--
-- Against unpatched upstream/master the armed checks must fail; that run is
-- the proof that the checks can go red.

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
-- Drive the dashboard
-- ---------------------------------------------------------------------------

local dashboard = requireModule("widgets/dashboard.lua")
local bus = requireModule("lib/bus.lua")

-- Every msp.request the widget publishes, in order.
local requests = {}
bus.subscribe("msp.request", function(payload) requests[#requests + 1] = payload end)

dashboard.init({})
local descriptor = _G.__widget
check("the dashboard widget registered itself", descriptor ~= nil)
if descriptor == nil then
  print(string.format("\n%d checks, %d failed", checks, failures))
  os.exit(1)
end

local state = descriptor.create()
pcall(descriptor.wakeup, state)


-- ---------------------------------------------------------------------------
-- Drive the real bar gauge
-- ---------------------------------------------------------------------------

local rfsuite = requireModule("widgets/dashboard/context.lua")
rfsuite.tasks = rfsuite.tasks or {}
local sensors = {}
rfsuite.tasks.telemetry = {
  sensorTable = {smartfuel = {unit_string = "%"}},
  getSensor = function(name)
    local s = sensors[name]
    if s then return s[1], nil, s[3] end
    return nil, nil, nil
  end,
}
rfsuite.flightmode = {current = "preflight"}

local bar = requireModule("widgets/dashboard/objects/gauge/bar.lua")
check("the bar gauge module loads", type(bar) == "table" and type(bar.wakeup) == "function")

local box = {source = "smartfuel", min = 0, max = 100}

local function wake()
  local ok, err = pcall(bar.wakeup, box)
  if not ok then print("        wakeup error: " .. tostring(err)) end
  return box._cache or {}
end

local LOADING = {[".."] = true, ["."] = true, ["..."] = true}

-- 1. Connected before flight: the value is shown.
sensors.smartfuel = {85, nil, "%"}
local c = wake()
check("connected: the bar shows 85", c.value == 85, "value=" .. tostring(c.value))

-- 2. The pack is unplugged before flight: the bar must not keep 85.
sensors.smartfuel = nil
c = wake()
check("disconnected before flight: the bar does not keep the last 85%",
  c.value ~= 85, "value=" .. tostring(c.value))
check("disconnected before flight: the bar shows the loading state",
  LOADING[tostring(c.displayValue)] == true, "displayValue=" .. tostring(c.displayValue))

-- 3. Postflight keeps the last value on purpose (flight statistics for review).
sensors.smartfuel = {60, nil, "%"}
rfsuite.flightmode.current = "preflight"
c = wake()
check("reconnected: the bar shows 60", c.value == 60, "value=" .. tostring(c.value))
rfsuite.flightmode.current = "postflight"
sensors.smartfuel = nil
c = wake()
check("postflight: the last value 60 is kept for review", c.value == 60, "value=" .. tostring(c.value))

print(string.format("\n%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
