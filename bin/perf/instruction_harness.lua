-- Shared harness for the off-device instruction-count measurements in this
-- directory (measure_dashboard_instructions.lua, measure_bg_instructions.lua).
--
-- Ethos aborts a Lua callback with "Max instructions count reached" once it
-- has executed a fixed number of VM instructions (20000 per callback). Ethos
-- offers no way to see how close a callback runs, and debug.sethook is not
-- something to rely on on the radio, so this runs the suite's real code on
-- desktop Lua 5.4 against stubbed Ethos APIs and counts VM instructions with
-- a count hook -- the same unit the limit is expressed in.
--
-- Only instructions executed by functions defined under src/rfsuite/ are
-- counted. The stubs here stand in for Ethos C functions, which cost the radio
-- one call instruction (already counted at the call site), so their own Lua
-- bodies must not inflate the figures.
--
-- What the numbers are NOT: wall time, or an exact radio figure. Stubbed lcd
-- calls return fixed sizes, so font-fit loops may iterate a different number
-- of times than on hardware, and sensors return whatever the driver feeds.
-- Read results as a ranking plus headroom against the limit.

local H = {}

H.LIMIT = 20000

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

-- The suite resolves every path relative to src/rfsuite.
local ROOT = (scriptDir() .. "/../../src/rfsuite"):gsub("\\", "/")
H.ROOT = ROOT

local function rooted(path)
  if type(path) ~= "string" then return path end
  local rest = path:match("^SCRIPTS:/rfsuite/(.*)$")
  if rest then return ROOT .. "/" .. rest end
  if not path:match("^%a:") and path:sub(1, 1) ~= "/" then return ROOT .. "/" .. path end
  return path
end

-- ---------------------------------------------------------------------------
-- Instruction counter
-- ---------------------------------------------------------------------------
local count = 0
local profiling = false
local selfProfile, inclusiveProfile = {}, {}
local isSuite = setmetatable({}, {__mode = "k"})
local getinfo = debug.getinfo

local function suiteKey(info)
  return info.short_src:gsub("^.*src/rfsuite/", "") .. ":" .. info.linedefined
end

-- Optional emulation of the limit itself, for checking what the suite does
-- when a callback is cut off. Ethos's exact semantics are not documented, so
-- both plausible ones are offered:
--   "once"  : one catchable error when a callback reaches LIMIT;
--   "sticky": an error on every counted instruction from LIMIT until the
--             callback returns, so recovery code inside it is cut off too.
local enforceMode = nil
local callbackDepth, callbackStart, enforcedFired = 0, 0, false
function H.enforceLimit(mode) enforceMode = mode end

local function hook()
  local f = getinfo(2, "f").func
  local suite = isSuite[f]
  if suite == nil then
    suite = getinfo(f, "S").source:find("/src/rfsuite/", 1, true) ~= nil
    isSuite[f] = suite
  end
  if not suite then return end
  count = count + 1
  if enforceMode and callbackDepth > 0 and count - callbackStart >= H.LIMIT then
    if enforceMode == "sticky" or not enforcedFired then
      enforcedFired = true
      error("Max instructions count reached", 0)
    end
  end
  if profiling then
    local key = suiteKey(getinfo(2, "S"))
    selfProfile[key] = (selfProfile[key] or 0) + 1
    -- Inclusive: charge every distinct suite function on the stack once.
    local level, seen = 2, {}
    while true do
      local fi = getinfo(level, "fS")
      if not fi then break end
      if isSuite[fi.func] and not seen[fi.func] then
        seen[fi.func] = true
        local k = suiteKey(fi)
        inclusiveProfile[k] = (inclusiveProfile[k] or 0) + 1
      end
      level = level + 1
    end
  end
end

function H.count() return count end
function H.start() debug.sethook(hook, "", 1) end
function H.stop() debug.sethook() end
function H.setProfiling(on) profiling = on and true or false end

local function printTop(title, t, n)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return t[a] > t[b] end)
  print("  " .. title)
  for i = 1, math.min(n, #keys) do print(string.format("    %6d %s", t[keys[i]], keys[i])) end
end

function H.printProfile(label, n)
  n = n or 25
  printTop("PROFILE " .. label .. " -- self instructions by function:", selfProfile, n)
  printTop("INCLUSIVE (function and everything it called):", inclusiveProfile, n)
end

-- Silence the suite's prints, keeping lines the driver wants to count.
local realPrint = print
H.print = realPrint
local printWatch = {}
function H.watchPrint(pattern)
  printWatch[pattern] = 0
end
function H.watched(pattern) return printWatch[pattern] or 0 end
print = function(...)
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do parts[i] = tostring((select(i, ...))) end
  local line = table.concat(parts, " ")
  for pattern, c in pairs(printWatch) do
    if line:find(pattern, 1, true) then printWatch[pattern] = c + 1 end
  end
end

local seenErrors = {}
-- Runs fn under pcall and returns the instructions it took.
function H.measure(fn, ...)
  local c0 = count
  -- The outermost measure() is one Ethos callback: the unit the limit applies to.
  if callbackDepth == 0 then callbackStart, enforcedFired = count, false end
  callbackDepth = callbackDepth + 1
  local ok, err = pcall(fn, ...)
  callbackDepth = callbackDepth - 1
  if not ok then
    local msg = tostring(err)
    if not seenErrors[msg] then
      seenErrors[msg] = true
      realPrint("ERROR: " .. msg)
    end
  end
  return count - c0
end

-- ---------------------------------------------------------------------------
-- Clock
-- ---------------------------------------------------------------------------
H.now = 100.0
os.clock = function() return H.now end
function H.advance(seconds) H.now = H.now + seconds end

-- ---------------------------------------------------------------------------
-- Ethos stubs
-- ---------------------------------------------------------------------------
local function noop() end
H.noop = noop
local function permissive(t)
  return setmetatable(t, {__index = function(self, k) rawset(self, k, noop); return noop end})
end
H.permissive = permissive

-- Upper-case globals (FONT_XS, CATEGORY_TELEMETRY_SENSOR, UNIT_VOLT, ...) are
-- Ethos constants; any stable number will do.
setmetatable(_G, {__index = function(_, k)
  if type(k) == "string" and k:match("^[A-Z][A-Z0-9_]+$") then
    local id = 0
    for i = 1, #k do id = (id * 31 + k:byte(i)) % 65536 end
    rawset(_G, k, id)
    return id
  end
  return nil
end})

H.window = {w = 800, h = 480}

local function newBitmap()
  return permissive({width = function() return 64 end, height = function() return 64 end})
end

lcd = permissive({
  getWindowSize = function() return H.window.w, H.window.h end,
  getTextSize = function(s) s = tostring(s or ""); return #s * 9, 18 end,
  RGB = math.max,
  themeColor = function() return 0x808080 end,
  isVisible = function() return true end,
  darkMode = function() return true end,
  loadMask = newBitmap,
  loadBitmap = newBitmap,
  loadImage = newBitmap,
})

-- Every telemetry source reads H.sensorValue, so a driver can make values move,
-- and reports H.linkUp as its state (TELEMETRY_ACTIVE included).
H.sensorValue = 12.3
H.linkUp = true
local function newSource()
  return permissive({
    value = function() return H.sensorValue end,
    state = function() return H.linkUp end,
    name = function() return "src" end,
    unit = function() return 0 end,
    decimals = function() return 1 end,
  })
end
H.newSource = newSource

H.registered = {widgets = {}, tasks = {}, tools = {}}
system = permissive({
  getVersion = function()
    return {simulation = false, major = 1, minor = 6, revision = 3, board = "X20S",
      lcdWidth = 800, lcdHeight = 480, version = "1.6.3"}
  end,
  getSource = function() return newSource() end,
  getMemoryUsage = function() return {} end,
  registerWidget = function(def) table.insert(H.registered.widgets, def) end,
  registerTask = function(def) table.insert(H.registered.tasks, def) end,
  registerSystemTool = function(def) table.insert(H.registered.tools, def); return def end,
  getLocale = function() return "en" end,
})

-- RF modules: none by default (S.Port fallback). H.useCrsf() makes the
-- external module an enabled CRSF one.
local modules = {}
model = permissive({
  name = function() return "Bench" end,
  getModule = function(i) return modules[i] end,
  createSensor = function() return newSource() end,
  path = function() return "MODELS:/bench.bin" end,
})
form = permissive({})

-- CRSF: frames the driver queues per frame type are handed back by popFrame.
H.crsfQueues = {}
local crsfSensor = permissive({
  popFrame = function(_, frameType)
    local q = H.crsfQueues[frameType]
    if not q or #q == 0 then return nil end
    local frame = table.remove(q, 1)
    return frameType, frame
  end,
  pushFrame = function() return true end,
})
crsf = permissive({getSensor = function() return crsfSensor end})
sport = permissive({getSensor = function() return permissive({popFrame = noop, pushFrame = function() return true end}) end})
function H.useCrsf()
  modules[1] = permissive({enable = function() return true end})
end

-- ---------------------------------------------------------------------------
-- Files and settings
-- ---------------------------------------------------------------------------
local realLoadfile = loadfile
local realOpen = io.open
io.open = function(path, mode)
  if type(path) == "string" and path:match("^%u+:") then return nil end
  return realOpen(rooted(path), mode)
end

-- Module body cost: a chunk's top level (tables, function definitions, its own
-- dependencies) is paid by whichever Ethos callback first needs the module.
H.moduleLoads = {}
H.chunkWrappers = {}   -- functions(path, chunk) -> chunk, applied in order
loadfile = function(path, ...)
  local chunk, err = realLoadfile(rooted(path), ...)
  if not chunk then return chunk, err end
  local timed = function(...)
    local c0 = count
    local r = table.pack(chunk(...))
    H.moduleLoads[#H.moduleLoads + 1] = {path = tostring(path), cost = count - c0}
    return table.unpack(r, 1, r.n)
  end
  for _, wrap in ipairs(H.chunkWrappers) do timed = wrap(path, timed) end
  return timed
end

-- Settings come from H.settings instead of SCRIPTS:/rfsuite.user.
H.settings = {}
local ini = assert(loadfile("lib/ini.lua"))()
package.loaded["rfsuite.lib.ini"] = ini
ini.load_ini_file = function() return H.settings end
ini.save_ini_file = function() return true end

function H.printModuleLoads(n)
  table.sort(H.moduleLoads, function(a, b) return a.cost > b.cost end)
  for i = 1, math.min(n or 8, #H.moduleLoads) do
    print(string.format("  LOAD %6d %s", H.moduleLoads[i].cost, H.moduleLoads[i].path))
  end
end

-- A session.update payload as tasks/session.lua's flush() builds it, with
-- values that move every call so change detection fires.
local snapshotTick = 0
function H.sessionSnapshot(armed)
  snapshotTick = snapshotTick + 1
  local t = snapshotTick
  return {
    connected = true, isArmed = armed == true, apiVersionSupported = true,
    craftName = "Bench", mcuId = "abc123", fcVersion = "1.0.0", rfVersion = "12.09",
    apiVersionMajor = 12, apiVersionMinor = 9,
    voltage = 22.2 - t * 0.01, current = 10 + (t % 7), consumption = 100 + t,
    throttlePercent = 40 + (t % 20), rpm = 2000 + (t % 50), linkQuality = 90 - (t % 10),
    tempEsc = 40 + (t % 5), tempMcu = 35 + (t % 3), becVoltage = 5.1, fuelPercent = 100 - (t % 100),
    pidProfile = 1, rateProfile = 1, batteryProfile = 1,
    timerLive = t * 0.05, timerSession = t * 0.05, timerTarget = 300,
    batteryConfig = {cellCount = 6, vbatMinCell = 330, vbatFullCell = 420, batteryCapacity = 5000,
      consumptionWarningPercentage = 30, profiles = {}},
    modelStats = {flightcount = 3, totalflighttime = 600, lastflighttime = 120},
    systemStatus = {raw = 0}, armDisableFlags = 0, bblFlags = 0, bblSize = 1000, bblUsed = 10,
    handshake = {},
  }
end

return H
