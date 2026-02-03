--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = { ... }
local config = arg[1]

-- Localise hot globals to reduce global/table lookups
local os_clock = os.clock
local os_date  = os.date
local os_time  = os.time
local io_open  = io.open
local type     = type
local ipairs   = ipairs
local tostring = tostring
local math_floor = math.floor
local math_min   = math.min
local table_concat = table.concat
local table_insert = table.insert

local logging = {}

-- Queue / flushing policy
local MAX_QUEUE = 200                 -- bigger queue so we can batch better
local FLUSH_QUEUE_SIZE = 20
local DISK_WRITE_INTERVAL = 2.5
local DISK_BUFFER_MAX_BYTES = 4096
local DISK_KEEP_OPEN = true

local logInterval = 1                 -- seconds between log samples
local logFileName
local logRateLimit = os_clock()
local logHeader

local telemetry
local logDirChecked = false
local lastDiskFlush = os_clock()

local log_queue = {}
local log_queue_bytes = 0

-- Cache these while a session is active to avoid repeated deep table traversals
local cachedMcuId
local cachedBaseDir
local cachedIniPath
local cachedFilePath

-- Optional: cache telemetry sources while logging (avoids repeated getSensorSource calls)
local sourcesCached = false
local sensorSources = {}

local colorTable = {}

if lcd.darkMode() then
    colorTable["voltage"] = COLOR_RED
    colorTable["current"] = COLOR_ORANGE
    colorTable["rpm"] = COLOR_GREEN
    colorTable["temp_esc"] = COLOR_CYAN
    colorTable["throttle_percent"] = COLOR_YELLOW
else
    colorTable["voltage"] = lcd.RGB(200, 0, 0)
    colorTable["current"] = lcd.RGB(220, 100, 0)
    colorTable["rpm"] = lcd.RGB(0, 140, 0)
    colorTable["temp_esc"] = lcd.RGB(0, 80, 200)
    colorTable["throttle_percent"] = lcd.RGB(180, 160, 0)
end

local logTable = {
    {name = "voltage", keyindex = 1, keyname = "Voltage", keyunit = "v", keyminmax = 1, color = colorTable['voltage'], pen = SOLID, graph = true},
    {name = "current", keyindex = 2, keyname = "Current", keyunit = "A", keyminmax = 1, color = colorTable['current'], pen = SOLID, graph = true},
    {name = "rpm", keyindex = 3, keyname = "Headspeed", keyunit = "rpm", keyminmax = 1, keyfloor = true, color = colorTable['rpm'], pen = SOLID, graph = true},
    {name = "temp_esc", keyindex = 4, keyname = "Esc. Temperature", keyunit = "°", keyminmax = 1, color = colorTable['temp_esc'], pen = SOLID, graph = true},
    {name = "throttle_percent", keyindex = 5, keyname = "Throttle %", keyunit = "%", keyminmax = 1, color = colorTable['throttle_percent'], pen = SOLID, graph = true}
}

-- --- Disk handle caching ----------------------------------------------------

local diskFH
local diskFHPath

local function diskClose()
    if diskFH then
        pcall(function() diskFH:close() end)
        diskFH = nil
        diskFHPath = nil
    end
end

local function diskEnsureOpen(path)
    if not path or path == "" then return nil end
    if diskFH and diskFHPath == path then return diskFH end
    diskClose()
    local f = io_open(path, "a")
    if not f then return nil end
    diskFH = f
    diskFHPath = path
    return f
end

local function isDebugEnabled()
    local pref = rfsuite.preferences
    if not pref then return false end
    local dev = pref.developer
    if not dev then return false end
    return dev.loglevel == "debug"
end

-- --- Paths / dirs -----------------------------------------------------------

local function generateLogFilename()
    local timestamp = os_date("%Y-%m-%d_%H-%M-%S")
    local uniquePart = math_floor(os_clock() * 1000)
    return timestamp .. "_" .. uniquePart .. ".csv"
end

local function checkLogdirExists(mcu_id)
    -- NOTE: keep LOGS:/ path consistent (your old code mixed LOGS: and LOGS:/)
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/telemetry")
    os.mkdir("LOGS:/rfsuite/telemetry/" .. mcu_id)
end

local function refreshSessionCaches(session)
    local mcu_id = session and session.mcu_id
    if not mcu_id then return false end

    if cachedMcuId ~= mcu_id then
        cachedMcuId = mcu_id
        cachedBaseDir = "LOGS:/rfsuite/telemetry/" .. mcu_id
        cachedIniPath = cachedBaseDir .. "/logs.ini"
        cachedFilePath = nil -- depends on logFileName
        logDirChecked = false
        sourcesCached = false
        sensorSources = {}
    end
    return true
end

local function cacheFilePath()
    if not cachedBaseDir or not logFileName then return nil end
    cachedFilePath = cachedBaseDir .. "/" .. logFileName
    return cachedFilePath
end

local function cacheTelemetrySources()
    if sourcesCached or not telemetry then return end
    for i, sensor in ipairs(logTable) do
        local src = telemetry.getSensorSource and telemetry.getSensorSource(sensor.name)
        sensorSources[i] = src
    end
    sourcesCached = true
end

-- --- Queue / flushing -------------------------------------------------------

function logging.queueLog(line)
    if not line then return end
    table_insert(log_queue, line)
    log_queue_bytes = log_queue_bytes + #line + 1 -- + newline
    if #log_queue >= MAX_QUEUE then
        logging.writeLogs(true)
    end
end

local function dropQueuePrefix(n)
    if n <= 0 then return end
    local total = #log_queue
    if n >= total then
        for i = 1, total do log_queue[i] = nil end
        log_queue_bytes = 0
        return
    end
    table.move(log_queue, n + 1, total, 1)
    for i = total - n + 1, total do log_queue[i] = nil end

    -- Recompute bytes cheaply only when we do a partial drop (rare)
    local bytes = 0
    for i = 1, (total - n) do
        local s = log_queue[i]
        if s then bytes = bytes + #s + 1 end
    end
    log_queue_bytes = bytes
end

function logging.writeLogs(forcewrite)
    if #log_queue == 0 then return end
    if not logFileName then return end

    local filePath = cachedFilePath or cacheFilePath()
    if not filePath then return end

    local max_lines = forcewrite and #log_queue or 50
    local n = math_min(#log_queue, max_lines)
    if n <= 0 then return end

    if isDebugEnabled() then
        -- Avoid string.format cost unless debug really enabled
        rfsuite.utils.log("Write " .. tostring(n) .. " (of " .. tostring(#log_queue) .. ") lines to " .. tostring(logFileName), "debug")
    end

    local f
    if DISK_KEEP_OPEN then
        f = diskEnsureOpen(filePath)
    else
        f = io_open(filePath, "a")
    end
    if not f then
        -- If we can't open the file, avoid unbounded growth
        dropQueuePrefix(n)
        return
    end

    -- One write call for the whole chunk is much cheaper than line-by-line.
    local ok = pcall(function()
        f:write(table_concat(log_queue, "\n", 1, n))
        f:write("\n")
        if f.flush then f:flush() end
    end)

    if not DISK_KEEP_OPEN then
        pcall(function() f:close() end)
    end

    if not ok then
        -- If the file handle went bad, close it so we reopen next time.
        diskClose()
        -- Drop what we attempted to write to keep system responsive.
        dropQueuePrefix(n)
        return
    end

    dropQueuePrefix(n)
end

-- --- Log line generation ----------------------------------------------------

function logging.getLogHeader()
    local names = {}
    for i, sensor in ipairs(logTable) do
        names[i] = sensor.name
    end
    -- Avoid joinTableItems lookup + extra allocations
    return "time, " .. table_concat(names, ", ")
end

function logging.getLogLine()
    local values = {}
    -- If cached sources exist, prefer them
    for i, sensor in ipairs(logTable) do
        local src = sensorSources[i]
        if not src and telemetry and telemetry.getSensorSource then
            src = telemetry.getSensorSource(sensor.name)
            sensorSources[i] = src
        end
        values[i] = (src and src.value and src:value()) or 0
    end
    local ts = os_time()
    return ts .. ", " .. table_concat(values, ", ")
end

function logging.getLogTable()
    return logTable
end

function logging.flushLogs()
    if logFileName or logHeader then
        rfsuite.utils.log("Flushing logs - " .. tostring(logFileName), "info")
        logging.writeLogs(true)
        logFileName, logHeader = nil, nil
        cachedFilePath = nil
        sourcesCached = false
        sensorSources = {}
        log_queue_bytes = 0
        diskClose()
    end
end

function logging.reset()
    logging.flushLogs()
end

-- --- Main loop --------------------------------------------------------------

function logging.wakeup()
    local session = rfsuite.session
    if not session or not session.mcu_id then return end
    if not refreshSessionCaches(session) then return end

    if not telemetry then
        telemetry = rfsuite.tasks and rfsuite.tasks.telemetry
        return
    end

    if not logDirChecked then
        checkLogdirExists(cachedMcuId)
        logDirChecked = true
    end

    if not telemetry.active() then
        logging.flushLogs()
        return
    end

    if rfsuite.utils.inFlight() then
        if not logFileName then
            logFileName = generateLogFilename()
            cacheFilePath()
            lastDiskFlush = os_clock()
            rfsuite.utils.log("Logging triggered by inFlight() - " .. logFileName, "info")

            local iniData = rfsuite.ini.load_ini_file(cachedIniPath) or {}
            if not iniData.model then iniData.model = {} end
            iniData.model.name = session.craftName or model.name() or "Unknown"
            rfsuite.ini.save_ini_file(cachedIniPath, iniData)

            sourcesCached = false
            sensorSources = {}
        end

        if not logHeader then
            local filePath = cachedFilePath or cacheFilePath()
            local f = io_open(filePath, "w")
            if f then
                -- Use direct method calls (less indirection than io.write(f,...))
                f:write(logging.getLogHeader(), "\n")
                f:close()
                logHeader = true
            else
                return
            end
        end

        -- Cache sensor sources once we are actively logging
        cacheTelemetrySources()

        local now = os_clock()
        if (now - logRateLimit) >= logInterval then
            logRateLimit = now
            logging.queueLog(logging.getLogLine())
        end

        -- Flush policy: size OR time-based
        local dueBySize = (#log_queue >= FLUSH_QUEUE_SIZE) or (log_queue_bytes >= DISK_BUFFER_MAX_BYTES)
        local dueByTime = (now - lastDiskFlush) >= DISK_WRITE_INTERVAL

        if dueBySize or dueByTime then
            lastDiskFlush = now
            logging.writeLogs(false)
        end
    else
        logging.flushLogs()
    end
end

return logging
