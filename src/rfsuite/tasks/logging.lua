-- Flight telemetry CSV logger, owned by the background task.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local debugLog = requireModule("lib/debug_log.lua")
local ini = requireModule("lib/ini.lua")
local atomicWrite = requireModule("lib/atomic_write.lua")

local FLUSH_INTERVAL = 2.5
local FLUSH_QUEUE_SIZE = 20
local MAX_QUEUE = 80

local LOG_COLUMNS = {
  {name = "voltage", label = "voltage"},
  {name = "current", label = "current"},
  {name = "rpm", label = "rpm"},
  {name = "temp_esc", label = "temp_esc"},
  {name = "throttle_percent", label = "throttle_percent"},
}

local session = {}
local telemetrySensors = nil
local settings = nil
local log = {
  active = false,
  fileName = nil,
  filePath = nil,
  dir = nil,
  modelName = nil,
  fileHandle = nil,
  queue = {},
  -- The last failure line already printed, so a streak that persists for a
  -- whole flight costs one line instead of one per flush -- see
  -- reportFailure() below. Cleared by the next successful write.
  reported = nil,
  lastSample = 0,
  lastFlush = 0,
}

local function safeMkdir(path)
  if os and os.mkdir then pcall(os.mkdir, path) end
end

local function modelName()
  if session.craftName and session.craftName ~= "" then return session.craftName end
  if model and model.name then
    local ok, name = pcall(model.name)
    if ok and name and name ~= "" then return name end
  end
  return "Unknown"
end

local function ensureDir()
  if not session.mcuId or session.mcuId == "" then return nil end
  safeMkdir("LOGS:")
  safeMkdir("LOGS:/rfsuite")
  safeMkdir("LOGS:/rfsuite/telemetry")
  local dir = "LOGS:/rfsuite/telemetry/" .. session.mcuId
  safeMkdir(dir)
  return dir
end

local function writeModelIni(dir, name)
  -- Via ini.save_ini_file() rather than a hand-rolled io.open(): the model
  -- name is rewritten whenever the connected craft reports a different one,
  -- and a truncating write there loses the name the logs page shows.
  return ini.save_ini_file(dir .. "/logs.ini", {model = {name = name or modelName()}})
end

local function updateModelIni()
  if not log.active or not log.dir then return end
  local name = modelName()
  if name == log.modelName then return end
  log.modelName = name
  writeModelIni(log.dir, name)
end

local function generateFileName()
  return os.date("%Y-%m-%d_%H-%M-%S") .. "_" .. tostring(math.floor(os.clock() * 1000)) .. ".csv"
end

local function headerLine()
  local labels = {}
  for i = 1, #LOG_COLUMNS do labels[i] = LOG_COLUMNS[i].label end
  return "time, " .. table.concat(labels, ", ")
end

local function sensorValue(protocol, name)
  if not telemetrySensors then return 0 end
  local value = telemetrySensors.getValue(protocol, name)
  if value == nil then return 0 end
  return value
end

local function sampleLine(protocol)
  local values = {}
  for i = 1, #LOG_COLUMNS do
    values[i] = tostring(sensorValue(protocol, LOG_COLUMNS[i].name))
  end
  return tostring(os.time()) .. ", " .. table.concat(values, ", ")
end

local function closeHandle()
  if log.fileHandle then
    pcall(function() log.fileHandle:close() end)
    log.fileHandle = nil
  end
end

-- Both failure paths below used to shorten the queue anyway: an io.open that
-- failed emptied it outright, and a failed write() trimmed the rows it had just
-- failed to persist. Either way the samples the flight controller had already
-- handed over were gone, with nothing written anywhere about it -- a flight log
-- that quietly stops recording is indistinguishable from one that worked.
--
-- Reported once per streak rather than once per tick. flush() runs every 2.5s
-- for as long as the queue is non-empty, so a line per tick would bury
-- everything else. Unconditional rather than behind debugLog, for the same
-- reason tasks/session.lua's own FLIGHT_STATS failures are: this is a pilot's
-- data, not a developer's trace.
--
-- `key` is deliberately not the message: the sample count in it changes on
-- every tick, and folding that into the comparison turned a one-line report
-- into one line per flush the first time this was written.
--
-- Holding the rows cannot grow without limit -- MAX_QUEUE in wakeup() below
-- already drops the oldest past 80, so an unwritable card costs the samples
-- taken while it was gone and then stops, instead of the whole buffer at once.
local function reportFailure(key, message)
  if log.reported == key then return end
  log.reported = key
  print("[logging] " .. message)
end

local function flush(force)
  if #log.queue == 0 or not log.filePath then return end

  local file = log.fileHandle
  if not file then
    file = io.open(log.filePath, "a")
    log.fileHandle = file
  end
  if not file then
    -- Keep the queue: the card may well come back before the flight ends, and
    -- these rows are the only record of what it did in the meantime.
    reportFailure("open", "cannot open " .. tostring(log.filePath)
      .. " -- keeping " .. #log.queue .. " samples")
    return
  end

  local count = force and #log.queue or math.min(#log.queue, 50)
  local ok = pcall(function()
    file:write(table.concat(log.queue, "\n", 1, count))
    file:write("\n")
    if file.flush then file:flush() end
  end)
  if not ok then
    closeHandle()
    reportFailure("write", "write to " .. tostring(log.filePath)
      .. " failed -- keeping " .. #log.queue .. " samples")
    return
  end
  log.reported = nil

  if count >= #log.queue then
    for i = #log.queue, 1, -1 do log.queue[i] = nil end
  else
    local remaining = #log.queue - count
    for i = 1, remaining do log.queue[i] = log.queue[i + count] end
    for i = remaining + 1, remaining + count do log.queue[i] = nil end
  end
end

local function stop()
  if not log.active then return end
  flush(true)
  -- flush() keeps the rows when it could not write them, and a log that is
  -- ending has no next tick to retry on, so they are dropped here -- loudly,
  -- and counted. This is the only place the queue is emptied without a write,
  -- which is why start() below can rely on finding it empty for a new file.
  if #log.queue > 0 then
    reportFailure("end", "log ended with " .. #log.queue .. " unwritten samples in "
      .. tostring(log.filePath))
    for i = #log.queue, 1, -1 do log.queue[i] = nil end
  end
  closeHandle()
  log.active = false
  log.fileName = nil
  log.filePath = nil
  log.dir = nil
  log.modelName = nil
end

-- Hold the log open across a short link loss. The samples taken so far are
-- already in the file, the handle is closed so nothing is written while there
-- is no link, and the next flush reopens the same path in append mode -- so
-- one flight stays one file, and the peaks the log page derives from a file
-- stay the peaks of the whole flight. A new file here would put the two halves
-- of one flight into two records.
--
-- Unlike stop(), rows flush() could not write are kept rather than dropped:
-- this log resumes, so the next flush still has somewhere to put them.
local function pause()
  if not log.active then return end
  flush(true)
  closeHandle()
end

-- A flight that was in progress at link loss can still be resumed, so the log
-- is paused rather than stopped. flight_timer owns that decision and its grace
-- window, so there is exactly one place that says whether this is the same
-- flight.
--
-- A pilot who has disarmed ends the flight, even if the link only just came
-- back: the outage is not a reason to keep a record alive, and holding it here
-- is what would merge the next flight into this one. nil means "not known
-- yet", which is the normal state while the link is down, and holding is right.
local function holdAcrossLinkLoss()
  if session.isArmed == false then return false end
  return log.active and session.flightResumable == true
end

local function start()
  local dir = ensureDir()
  if not dir then return false end

  log.dir = dir
  log.modelName = modelName()
  writeModelIni(dir, log.modelName)
  log.fileName = generateFileName()
  log.filePath = dir .. "/" .. log.fileName
  log.lastSample = 0
  log.lastFlush = os.clock()

  -- Staged and swapped in, like every other file this suite writes: an
  -- interrupted write used to leave a 0-byte CSV in the telemetry folder,
  -- which the logs page then listed as a flight with nothing in it.
  if not atomicWrite.write(log.filePath, headerLine() .. "\n") then
    log.fileName = nil
    log.filePath = nil
    return false
  end

  log.active = true
  debugLog.print("[logging] started " .. log.fileName)
  return true
end

local function inFlight()
  return session.connected == true and session.isArmed == true and (session.mcuId ~= nil or log.active == true)
end

local function loggingEnabled()
  if not settings then settings = settingsStore.load() end
  return settingsStore.loggingEnabled(settings)
end

local function sampleInterval()
  if not settings then settings = settingsStore.load() end
  return settingsStore.loggingSampleInterval(settings)
end

local function onSessionUpdate(snapshot)
  for k in pairs(session) do session[k] = nil end
  for k, v in pairs(snapshot or {}) do session[k] = v end
  if inFlight() then
    -- Nothing to do: a log that is paused reopens the same file on the next
    -- flush, and one that is not active yet is started by wakeup().
  elseif holdAcrossLinkLoss() then
    pause()
  else
    stop()
  end
  updateModelIni()
end

local function onSettingsUpdate(snapshot)
  settings = snapshot or {}
end

bus.subscribe("session.update", onSessionUpdate)
bus.subscribe("settings.update", onSettingsUpdate)

local logging = {}

function logging.getLogTable()
  return LOG_COLUMNS
end

function logging.setTelemetrySensors(instance)
  telemetrySensors = instance
end

function logging.setSettings(snapshot)
  onSettingsUpdate(snapshot)
end

function logging.wakeup(protocol)
  if not loggingEnabled() then
    stop()
    return
  end
  if not inFlight() then
    if not holdAcrossLinkLoss() then
      stop()
    end
    return
  end
  if not log.active and not start() then return end

  local now = os.clock()
  if now - log.lastSample >= sampleInterval() then
    log.lastSample = now
    log.queue[#log.queue + 1] = sampleLine(protocol)
    if #log.queue > MAX_QUEUE then
      table.remove(log.queue, 1)
    end
  end

  if #log.queue >= FLUSH_QUEUE_SIZE or now - log.lastFlush >= FLUSH_INTERVAL then
    log.lastFlush = now
    flush(false)
  end
end

function logging.close()
  stop()
end

return logging
