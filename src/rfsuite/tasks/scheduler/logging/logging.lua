--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local MAX_QUEUE = 50
local FLUSH_QUEUE_SIZE = 2

local logging = {}
local logInterval = 1
local logFileName
local logRateLimit = os.clock()
local logHeader

local telemetry

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
    {name = "voltage", keyindex = 1, keyname = "Voltage", keyunit = "v", keyminmax = 1, color = colorTable['voltage'], pen = SOLID, graph = true}, {name = "current", keyindex = 2, keyname = "Current", keyunit = "A", keyminmax = 1, color = colorTable['current'], pen = SOLID, graph = true}, {name = "rpm", keyindex = 3, keyname = "Headspeed", keyunit = "rpm", keyminmax = 1, keyfloor = true, color = colorTable['rpm'], pen = SOLID, graph = true},
    {name = "temp_esc", keyindex = 4, keyname = "Esc. Temperature", keyunit = "°", keyminmax = 1, color = colorTable['temp_esc'], pen = SOLID, graph = true}, {name = "throttle_percent", keyindex = 5, keyname = "Throttle %", keyunit = "%", keyminmax = 1, color = colorTable['throttle_percent'], pen = SOLID, graph = true}
}

local log_queue = {}
local logDirChecked = false

local function generateLogFilename()
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local uniquePart = math.floor(os.clock() * 1000)
    return timestamp .. "_" .. uniquePart .. ".csv"
end

local function checkLogdirExists()
    os.mkdir("LOGS:")
    os.mkdir("LOGS:/rfsuite")
    os.mkdir("LOGS:/rfsuite/telemetry")
    os.mkdir("LOGS:/rfsuite/telemetry/" .. rfsuite.session.mcu_id)
end

function logging.queueLog(msg)
    table.insert(log_queue, msg)
    if #log_queue >= MAX_QUEUE then logging.writeLogs(true) end
end

function logging.writeLogs(forcewrite)
    local max_lines = forcewrite and #log_queue or 10
    if #log_queue > 0 and logFileName then
        local filePath = "LOGS:rfsuite/telemetry/" .. rfsuite.session.mcu_id .. "/" .. logFileName

        rfsuite.utils.log(string.format("Write %d (of %d) lines to %s", math.min(#log_queue, max_lines), #log_queue, logFileName), "info")

        local f = io.open(filePath, 'a')

        local n = math.min(#log_queue, max_lines)

        io.write(f, table.concat(log_queue, "\n", 1, n), "\n")

        local total = #log_queue
        if n < total then
            table.move(log_queue, n + 1, total, 1)
            for i = total - n + 1, total do log_queue[i] = nil end
        else
            for i = 1, total do log_queue[i] = nil end
        end

        io.close(f)
    end
end

function logging.getLogHeader()
    local names = {}
    for _, sensor in ipairs(logTable) do table.insert(names, sensor.name) end
    return "time, " .. rfsuite.utils.joinTableItems(names, ", ")
end

function logging.getLogLine()
    local values = {}
    for i, sensor in ipairs(logTable) do
        local src = telemetry and telemetry.getSensorSource(sensor.name)
        values[i] = src and src:value() or 0
    end
    local ts = os.time()
    return ts .. ", " .. rfsuite.utils.joinTableItems(values, ", ")
end

function logging.getLogTable() return logTable end

function logging.flushLogs()
    if logFileName or logHeader then
        rfsuite.utils.log("Flushing logs - " .. tostring(logFileName), "info")

        logging.writeLogs(true)
        logFileName, logHeader = nil, nil
        logdir = nil

    end
end

function logging.reset() end

function logging.wakeup()

    if not rfsuite.session.mcu_id then return end

    if not telemetry then
        telemetry = rfsuite.tasks.telemetry
        return
    end

    if not logDirChecked then
        checkLogdirExists()
        logDirChecked = true
    end

    if not telemetry.active() then
        logging.flushLogs()
        return
    end

    if rfsuite.utils.inFlight() then
        if not logFileName then
            logFileName = generateLogFilename()
            rfsuite.utils.log("Logging triggered by inFlight() - " .. logFileName, "info")

            local iniName = "LOGS:rfsuite/telemetry/" .. rfsuite.session.mcu_id .. "/logs.ini"
            local iniData = rfsuite.ini.load_ini_file(iniName) or {}
            if not iniData.model then iniData.model = {} end
            iniData.model.name = rfsuite.session.craftName or model.name() or "Unknown"
            rfsuite.ini.save_ini_file(iniName, iniData)
        end
        if not logHeader then

            local filePath = "LOGS:rfsuite/telemetry/" .. rfsuite.session.mcu_id .. "/" .. logFileName
            local f = io.open(filePath, 'w')
            if f then
                io.write(f, logging.getLogHeader(), "\n")
                io.close(f)
                logHeader = true
            end
        end

        if os.clock() - logRateLimit >= logInterval then
            logRateLimit = os.clock()
            logging.queueLog(logging.getLogLine())
            if #log_queue >= FLUSH_QUEUE_SIZE then logging.writeLogs() end
        end
    else
        logging.flushLogs()
    end
end

return logging
