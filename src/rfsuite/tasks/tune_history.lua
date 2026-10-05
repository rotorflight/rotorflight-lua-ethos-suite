-- Tune Advisor history, owned by the background task.
--
-- The FC's tune advisor statistics (lib/msp_tune_advisor.lua) live in its
-- RAM: they build up across flights, clear when the tune changes, and are
-- lost at power-off. On each disarm this reads all three axes and appends
-- them to a CSV per aircraft, so the radio keeps a trend the FC cannot:
--
--   LOGS:/rfsuite/tune/<mcuId>/history.csv
--
-- Beside it, logs.ini names the aircraft in the same format as the flight
-- log folders (app/pages/logs.lua). One row per axis per capture. The figures
-- are the FC's running totals, not one flight's: a row whose tune columns
-- (p .. s_rate) differ from the previous one, or whose flight_seconds
-- dropped, starts a new set (tune changed, Clear, or FC power-cycled).
--
-- Event-driven from "session.update", no scheduler job: a capture is armed
-- by a disarm and runs once the link and aircraft identity are there, so a
-- flight that ends during a link loss is still captured on reconnect (the
-- FC kept the numbers). Nothing is written when there is no rate flight to
-- record (flight_seconds 0, or unchanged since this aircraft's last row).
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local tuneAdvisor = requireModule("lib/msp_tune_advisor.lua")
local ini = requireModule("lib/ini.lua")

local BASE_DIR = "LOGS:/rfsuite/tune"
local RETRY_SECONDS = 5           -- after a link error, before asking again
local AXIS_NAMES = {"roll", "pitch", "yaw"}

local HEADER = "date,flight_seconds,axis,p,f,b,relax_cutoff,rates_type,rc_rate,s_rate,"
  .. "ff_count,ff_gain,ff_corr,ff_lag_ms,"
  .. "sp40_gain,sp40_count,sp100_gain,sp100_count,sp200_gain,sp200_count,"
  .. "coll0_gain,coll0_count,coll25_gain,coll25_count,coll50_gain,coll50_count,"
  .. "full_count,full_sat_count,full_ratio,full_max_rate,"
  .. "releases,big_rebounds,mean_rebound,mean_overshoot,mean_counter,mean_iterm"

local ROW_FMT = "%s,%d,%s,%d,%d,%d,%d,%d,%d,%d,"
  .. "%d,%.3f,%.3f,%d,"
  .. "%.3f,%d,%.3f,%d,%.3f,%d,"
  .. "%.3f,%d,%.3f,%d,%.3f,%d,"
  .. "%d,%d,%.3f,%d,"
  .. "%d,%d,%.3f,%.3f,%.3f,%.3f"

local lastArmed = nil             -- last known arm state; a link loss (nil) keeps it
local pending = false             -- a disarm has not been captured yet
local busy = false                -- reads are out
local retryAt = 0
local capture = {mcuId = nil, modelName = nil, replies = {}}
local lastSeconds = {}            -- by mcuId: flight_seconds of the last rows written

local function safeMkdir(path)
  if os and os.mkdir then pcall(os.mkdir, path) end
end

local function fileExists(path)
  local file = io.open(path, "rb")
  if not file then return false end
  pcall(function() file:close() end)
  return true
end

local function snapshotModelName(snapshot)
  if snapshot.craftName and snapshot.craftName ~= "" then return snapshot.craftName end
  if model and model.name then
    local ok, name = pcall(model.name)
    if ok and name and name ~= "" then return name end
  end
  return "Unknown"
end

local function row(date, seconds, axis, a)
  local sp, coll = a.spBands, a.collBands
  return string.format(ROW_FMT, date, seconds, AXIS_NAMES[axis],
    a.P, a.F, a.B, a.relaxCutoff, a.ratesType, a.rcRate, a.sRate,
    a.ffCount, a.ffGain, a.ffCorr, a.ffLagMs,
    sp[1].gain, sp[1].count, sp[2].gain, sp[2].count, sp[3].gain, sp[3].count,
    coll[1].gain, coll[1].count, coll[2].gain, coll[2].count, coll[3].gain, coll[3].count,
    a.fullCount, a.fullSatCount, a.fullRatio, a.fullMaxRate,
    a.releases, a.bigRebounds, a.meanRebound, a.meanOvershoot, a.meanCounter, a.meanIterm)
end

local function write()
  local mcuId, replies = capture.mcuId, capture.replies
  local seconds = replies[1].seconds
  if seconds == 0 or lastSeconds[mcuId] == seconds then return true end

  local dir = BASE_DIR .. "/" .. mcuId
  safeMkdir("LOGS:")
  safeMkdir("LOGS:/rfsuite")
  safeMkdir(BASE_DIR)
  safeMkdir(dir)
  if not fileExists(dir .. "/logs.ini") then
    ini.save_ini_file(dir .. "/logs.ini", {model = {name = capture.modelName}})
  end

  local path = dir .. "/history.csv"
  local isNew = not fileExists(path)
  local file = io.open(path, "a")
  if not file then
    print("[tune_history] cannot open " .. path)
    return false
  end
  local date = os.date("%Y-%m-%d %H:%M:%S")
  local ok = pcall(function()
    if isNew then file:write(HEADER, "\n") end
    for axis = 1, tuneAdvisor.AXIS_COUNT do
      file:write(row(date, seconds, axis, replies[axis].a), "\n")
    end
    if file.flush then file:flush() end
  end)
  pcall(function() file:close() end)
  if not ok then
    print("[tune_history] write to " .. path .. " failed")
    return false
  end
  lastSeconds[mcuId] = seconds
  return true
end

local function finish()
  busy = false
  pending = false
  for i = #capture.replies, 1, -1 do capture.replies[i] = nil end
end

local requestAxis

-- reason true is the FC's MSP error reply: no tune advisor in this firmware,
-- nothing to capture. Anything else is the link: try again shortly.
local function onError(reason)
  if reason == true then
    finish()
    return
  end
  busy = false
  retryAt = os.clock() + RETRY_SECONDS
  for i = #capture.replies, 1, -1 do capture.replies[i] = nil end
end

local function onData(data)
  local replies = capture.replies
  replies[#replies + 1] = data
  if #replies < tuneAdvisor.AXIS_COUNT then
    requestAxis(#replies + 1)
    return
  end
  if write() then
    finish()
  else
    busy = false
    retryAt = os.clock() + RETRY_SECONDS
    for i = #replies, 1, -1 do replies[i] = nil end
  end
end

requestAxis = function(axis)
  bus.publish("msp.request", tuneAdvisor.buildReadMessage(axis, onData, onError))
end

local function onSessionUpdate(snapshot)
  if not snapshot then return end
  local armed = snapshot.isArmed
  if armed == true then
    pending = false               -- the next disarm captures this flight too
  elseif armed == false and lastArmed == true then
    pending = true
    retryAt = 0
  end
  if armed ~= nil then lastArmed = armed end

  if not pending or busy or armed ~= false or snapshot.connected ~= true then return end
  if not snapshot.mcuId or snapshot.apiVersionSupported == false then return end
  if os.clock() < retryAt then return end

  busy = true
  capture.mcuId = snapshot.mcuId
  capture.modelName = snapshotModelName(snapshot)
  requestAxis(1)
end

bus.subscribe("session.update", onSessionUpdate)

return {}
