-- Flight telemetry CSV logger, owned by the background task.

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local settingsStore = requireModule("lib/settings_store.lua")
local debugLog = requireModule("lib/debug_log.lua")

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
  local path = dir .. "/logs.ini"
  local file = io.open(path, "w")
  if not file then return end
  file:write("[model]\n")
  file:write("name=", name or modelName(), "\n")
  file:close()
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

local function flush(force)
  if #log.queue == 0 or not log.filePath then return end

  local file = log.fileHandle
  if not file then
    file = io.open(log.filePath, "a")
    log.fileHandle = file
  end
  if not file then
    for i = #log.queue, 1, -1 do log.queue[i] = nil end
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
  end

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
  closeHandle()
  log.active = false
  log.fileName = nil
  log.filePath = nil
  log.dir = nil
  log.modelName = nil
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

  local file = io.open(log.filePath, "w")
  if not file then
    log.fileName = nil
    log.filePath = nil
    return false
  end
  file:write(headerLine(), "\n")
  file:close()

  log.active = true
  debugLog.print("[logging] started " .. log.fileName)
  return true
end

local function inFlight()
  return session.connected == true and session.isArmed == true and session.mcuId ~= nil
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
  if not inFlight() then stop() end
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
    stop()
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
