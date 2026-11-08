-- Behaviour check for the post-flight voltage stats of the dashboard text object
-- (#2663): the tiles show the voltage and cell count taken at the landing, not the
-- live values, which change once the pack is unplugged or the next one is plugged in.
--
-- Run it:
--     lua5.4 bin/dashboard_landing_stats/verify_dashboard_landing_stats.lua
--
-- Drives the real widgets/dashboard/objects/text/stats.lua (render.wakeup) with a
-- fake telemetry source. The live voltage is changed after the landing, and the
-- tiles must not follow it. Against the unpatched object the landing types show
-- nothing, so those checks fail.

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
-- Ethos stubs (the same surface the dashboard's own harnesses stub)
-- ---------------------------------------------------------------------------

FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L = 1, 2, 3, 4, 5
CENTERED, TEXT_LEFT = 16, 0

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
  registerWidget = function() end,
  killEvents = function() end,
  openPage = function() end,
  getMemoryUsage = function() return {mainStackAvailable = 4096} end,
  getVersion = function() return {simulation = false} end,
  voltageRange = function() return 7.2, 8.4 end,
  getSource = function() return nil end,
}
model = {bitmap = function() return nil end}

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
-- The fake telemetry: the live voltage can change; the landing and the flight's
-- lowest voltage are what the session keeps.
-- ---------------------------------------------------------------------------

local rfsuite = requireModule("widgets/dashboard/context.lua")
rfsuite.tasks = rfsuite.tasks or {}

local live = {voltage = 22.0}
local landing = nil
local flightStats = {voltage = {min = 21.6, max = 22.4}}

rfsuite.tasks.telemetry = {
  sensorTable = {voltage = {unit_string = "V"}},
  getSensor = function(name)
    if name == "voltage" then return live.voltage, nil, "V" end
    return nil, nil, nil
  end,
  getSensorStats = function(name) return flightStats[name] end,
  getLanding = function() return landing end,
}
rfsuite.flightmode = {current = "postflight"}

local stats = requireModule("widgets/dashboard/objects/text/stats.lua")
check("the stats text object loads", type(stats) == "table" and type(stats.wakeup) == "function")

local function wakeWith(stattype)
  local box = {source = "voltage", stattype = stattype, unit = "V"}
  local ok, err = pcall(stats.wakeup, box)
  if not ok then print("        wakeup error: " .. tostring(err)) end
  return box._cache or {}
end

-- The pack flown: 22.0 V at the disarm on 6 cells. Then the next pack goes in.
landing = {voltage = 22.0, cells = 6}
live.voltage = 24.6

-- 1. The voltage at the landing, not the live voltage.
local c = wakeWith("last")
check("the ending voltage is the landing voltage (22.0), not the live 24.6",
  c.displayValue == 22.0, "displayValue=" .. tostring(c.displayValue))

-- 2. The landing voltage per cell, two decimals (22.0 / 6 = 3.67).
c = wakeWith("lastcell")
check("the landing voltage per cell is 3.67, from the landing's own cell count",
  c.displayValue == 3.67, "displayValue=" .. tostring(c.displayValue))

-- 3. The lowest voltage of the flight per cell (21.6 / 6 = 3.6).
c = wakeWith("mincell")
check("the flight's lowest voltage per cell is 3.6",
  c.displayValue == 3.6, "displayValue=" .. tostring(c.displayValue))

-- 4. The cell count of the landing, not of the profile selected now: the landing
--    says 6, and a profile for 4 cells must not rescale the flight.
landing = {voltage = 22.0, cells = 6}
rfsuite.session = rfsuite.session or {}
rfsuite.session.batteryConfig = {cellCount = 4} -- the profile selected now
c = wakeWith("mincell")
check("the minimum per cell uses the flight's cell count, not the current profile's",
  c.displayValue == 3.6, "displayValue=" .. tostring(c.displayValue))

-- 5. No landing yet: nothing to show, so no number is invented.
landing = nil
c = wakeWith("lastcell")
check("with no landing the per-cell tile shows no number",
  type(c.displayValue) ~= "number", "displayValue=" .. tostring(c.displayValue))

-- 6. A landing without a cell count: no per-cell number either.
landing = {voltage = 22.0, cells = nil}
c = wakeWith("lastcell")
check("with no cell count at the landing the per-cell tile shows no number",
  type(c.displayValue) ~= "number", "displayValue=" .. tostring(c.displayValue))

print()
print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
