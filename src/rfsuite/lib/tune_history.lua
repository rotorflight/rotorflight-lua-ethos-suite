-- Tune Advisor flight history: the per-aircraft CSV that tasks/tune_history.lua
-- writes on each disarm and app/pages/tune_advisor.lua reads back.
--
--   LOGS:/rfsuite/tune/<mcuId>/history.csv   (mcuId: the session's aircraft ID)
--   LOGS:/rfsuite/tune/<mcuId>/logs.ini      (model name, as the flight log folders)
--
-- The FC's statistics are cleared after each capture, so a row is one flight.
-- One row per axis per flight; only the last MAX_FLIGHTS flights are kept,
-- since the page never looks further back.
--
-- aggregate() combines the newest flights flown on the newest flight's tune,
-- for one axis: counts add up, ratios are averaged weighted by the count they
-- came from. The FC's own gains are setpoint-squared weighted, so this is an
-- approximation across flights, close when flights are alike; the stop
-- figures (sums / releases on the FC) combine exactly.
--
-- Columns are this file's FIELDS, in order; tasks/ and app/ never spell them.
-- Self-caches via package.loaded (same mechanism lib/bus.lua uses).
if package.loaded["rfsuite.lib.tune_history"] then
  return package.loaded["rfsuite.lib.tune_history"]
end

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ini = requireModule("lib/ini.lua")
local atomicWrite = requireModule("lib/atomic_write.lua")

local BASE_DIR = "LOGS:/rfsuite/tune"
local MAX_FLIGHTS = 5
local AXIS_COUNT = 3
local AXIS_NAMES = {"roll", "pitch", "yaw"}
local BAND_COUNT = 3

-- {csv name, key in the decoded axis table, format}; band fields carry
-- band (the band table's key) and index.
local FIELDS = {
  {"p", "P", "%d"}, {"f", "F", "%d"}, {"b", "B", "%d"}, {"relax_cutoff", "relaxCutoff", "%d"},
  {"rates_type", "ratesType", "%d"}, {"rc_rate", "rcRate", "%d"}, {"s_rate", "sRate", "%d"},
  {"ff_count", "ffCount", "%d"}, {"ff_gain", "ffGain", "%.3f"}, {"ff_corr", "ffCorr", "%.3f"},
  {"ff_lag_ms", "ffLagMs", "%d"},
}
local function addBands(band, labels)
  for i = 1, BAND_COUNT do
    FIELDS[#FIELDS + 1] = {labels[i] .. "_gain", "gain", "%.3f", band = band, index = i}
    FIELDS[#FIELDS + 1] = {labels[i] .. "_count", "count", "%d", band = band, index = i}
  end
end
addBands("spBands", {"sp40", "sp100", "sp200"})
addBands("collBands", {"coll0", "coll25", "coll50"})
for _, f in ipairs({
  {"full_count", "fullCount", "%d"}, {"full_sat_count", "fullSatCount", "%d"},
  {"full_ratio", "fullRatio", "%.3f"}, {"full_max_rate", "fullMaxRate", "%d"},
  {"releases", "releases", "%d"}, {"big_rebounds", "bigRebounds", "%d"},
  {"mean_rebound", "meanRebound", "%.3f"}, {"mean_overshoot", "meanOvershoot", "%.3f"},
  {"mean_counter", "meanCounter", "%.3f"}, {"mean_iterm", "meanIterm", "%.3f"},
}) do FIELDS[#FIELDS + 1] = f end

-- The tune a flight was measured with: flights are only combined when these match
local TUNE_KEYS = {"P", "F", "B", "relaxCutoff", "ratesType", "rcRate", "sRate"}

local HEADER
do
  local names = {"date", "flight_seconds", "axis"}
  for _, f in ipairs(FIELDS) do names[#names + 1] = f[1] end
  HEADER = table.concat(names, ",")
end

local tuneHistory = {MAX_FLIGHTS = MAX_FLIGHTS, AXIS_COUNT = AXIS_COUNT}

local function safeMkdir(path)
  if os and os.mkdir then pcall(os.mkdir, path) end
end

local function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  pcall(function() file:close() end)
  return true
end

function tuneHistory.path(mcuId)
  return BASE_DIR .. "/" .. mcuId .. "/history.csv"
end

local function newAxis()
  local a = {spBands = {}, collBands = {}}
  for i = 1, BAND_COUNT do
    a.spBands[i] = {gain = 0, count = 0}
    a.collBands[i] = {gain = 0, count = 0}
  end
  for _, f in ipairs(FIELDS) do
    if not f.band then a[f[2]] = 0 end
  end
  return a
end

local function row(date, seconds, axis, a)
  local parts = {date, tostring(seconds), AXIS_NAMES[axis]}
  for _, f in ipairs(FIELDS) do
    local v = f.band and a[f.band][f.index][f[2]] or a[f[2]]
    parts[#parts + 1] = string.format(f[3], v or 0)
  end
  return table.concat(parts, ",")
end

local function splitLines(text)
  local lines = {}
  for line in text:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
  return lines
end

-- replies: three decoded lib/msp_tune_advisor.lua replies, roll/pitch/yaw.
-- Appends one flight and drops all but the newest MAX_FLIGHTS. Returns true
-- when written.
function tuneHistory.save(mcuId, modelName, replies)
  local dir = BASE_DIR .. "/" .. mcuId
  safeMkdir("LOGS:")
  safeMkdir("LOGS:/rfsuite")
  safeMkdir(BASE_DIR)
  safeMkdir(dir)
  if not fileExists(dir .. "/logs.ini") then
    ini.save_ini_file(dir .. "/logs.ini", {model = {name = modelName}})
  end

  local path = tuneHistory.path(mcuId)
  local keep = {}
  local text = ini.load_file_as_string(path)
  if text then
    local lines = splitLines(text)
    -- A file written with other columns is started again
    if lines[1] == HEADER then
      local first = math.max(2, #lines - (MAX_FLIGHTS - 1) * AXIS_COUNT + 1)
      for i = first, #lines do keep[#keep + 1] = lines[i] end
    end
  end

  local date = os.date("%Y-%m-%d %H:%M:%S")
  local seconds = replies[1].seconds
  local out = {HEADER}
  for i = 1, #keep do out[#out + 1] = keep[i] end
  for axis = 1, AXIS_COUNT do out[#out + 1] = row(date, seconds, axis, replies[axis].a) end
  out[#out + 1] = ""
  return atomicWrite.write(path, table.concat(out, "\n"))
end

function tuneHistory.erase(mcuId)
  if os and os.remove then pcall(os.remove, tuneHistory.path(mcuId)) end
end

-- Returns the saved flights, oldest first: {date, seconds, axes = {a, a, a}}.
-- A missing or foreign file reads as no flights.
function tuneHistory.read(mcuId)
  local flights = {}
  local text = ini.load_file_as_string(tuneHistory.path(mcuId))
  if not text then return flights end
  local lines = splitLines(text)
  if lines[1] ~= HEADER then return flights end

  local current = nil
  for i = 2, #lines do
    local cols = {}
    for v in (lines[i] .. ","):gmatch("([^,]*),") do cols[#cols + 1] = v end
    local axis = nil
    for n = 1, AXIS_COUNT do
      if AXIS_NAMES[n] == cols[3] then axis = n end
    end
    if axis and #cols == #FIELDS + 3 then
      if not current or current.date ~= cols[1] or current.axes[axis] then
        current = {date = cols[1], seconds = tonumber(cols[2]) or 0, axes = {}}
        flights[#flights + 1] = current
      end
      local a = newAxis()
      for n, f in ipairs(FIELDS) do
        local v = tonumber(cols[n + 3]) or 0
        if f.band then a[f.band][f.index][f[2]] = v else a[f[2]] = v end
      end
      current.axes[axis] = a
    end
  end
  return flights
end

local function sameTune(a, b)
  for _, k in ipairs(TUNE_KEYS) do
    if a[k] ~= b[k] then return false end
  end
  return true
end

-- weighted running mean: adds value v with weight w to out[key] over total
local function addMean(out, key, v, w, total)
  if total > 0 then out[key] = out[key] + (v - out[key]) * w / total end
end

local function addBand(bands, src)
  for i = 1, BAND_COUNT do
    local b, s = bands[i], src[i]
    b.count = b.count + s.count
    addMean(b, "gain", s.gain, s.count, b.count)
  end
end

-- One axis (1 roll, 2 pitch, 3 yaw) over the newest flights on the newest
-- flight's tune. Returns the combined axis table (shaped like a decoded reply's
-- `a`; all zeros with no flights), the flights used and their total seconds.
function tuneHistory.aggregate(flights, axis)
  local out = newAxis()
  local newest = flights[#flights] and flights[#flights].axes[axis]
  if not newest then return out, 0, 0 end
  for _, k in ipairs(TUNE_KEYS) do out[k] = newest[k] end

  local used, seconds = 0, 0
  for i = #flights, math.max(1, #flights - MAX_FLIGHTS + 1), -1 do
    local a = flights[i].axes[axis]
    if not a or not sameTune(a, newest) then break end
    used = used + 1
    seconds = seconds + flights[i].seconds

    out.ffCount = out.ffCount + a.ffCount
    addMean(out, "ffGain", a.ffGain, a.ffCount, out.ffCount)
    addMean(out, "ffCorr", a.ffCorr, a.ffCount, out.ffCount)
    addMean(out, "ffLagMs", a.ffLagMs, a.ffCount, out.ffCount)
    addBand(out.spBands, a.spBands)
    addBand(out.collBands, a.collBands)

    out.fullCount = out.fullCount + a.fullCount
    out.fullSatCount = out.fullSatCount + a.fullSatCount
    addMean(out, "fullRatio", a.fullRatio, a.fullCount, out.fullCount)
    if a.fullMaxRate > out.fullMaxRate then out.fullMaxRate = a.fullMaxRate end

    out.releases = out.releases + a.releases
    out.bigRebounds = out.bigRebounds + a.bigRebounds
    addMean(out, "meanRebound", a.meanRebound, a.releases, out.releases)
    addMean(out, "meanOvershoot", a.meanOvershoot, a.releases, out.releases)
    addMean(out, "meanCounter", a.meanCounter, a.releases, out.releases)
    addMean(out, "meanIterm", a.meanIterm, a.releases, out.releases)
  end
  out.ffLagMs = math.floor(out.ffLagMs + 0.5)
  return out, used, seconds
end

package.loaded["rfsuite.lib.tune_history"] = tuneHistory
return tuneHistory
