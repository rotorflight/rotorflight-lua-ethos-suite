--[[

 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 * Some icons sourced from https://www.flaticon.com/

]]--
local arg = {...}
local config = arg[1]

local logging = {}
local logInterval = 1 -- changing this will skew the log analysis - so dont change it
local logFileName
local logRateLimit = os.clock()

local colorTable = {}

if lcd.darkMode() then
    colorTable["voltage"] = COLOR_RED
    colorTable["current"] = COLOR_ORANGE
    colorTable["rpm"] = COLOR_GREEN
    colorTable["temp_esc"] = COLOR_CYAN
    colorTable["throttle_percent"] = COLOR_YELLOW
else
    colorTable["voltage"] = lcd.RGB(200, 0, 0)  -- Bright red
    colorTable["current"] = lcd.RGB(220, 100, 0)  -- Deep orange
    colorTable["rpm"] = lcd.RGB(0, 140, 0)  -- Strong green
    colorTable["temp_esc"] = lcd.RGB(0, 80, 200)  -- Bold blue
    colorTable["throttle_percent"] = lcd.RGB(180, 160, 0)  -- Deep gold
end

local logTable = {
    {name = "voltage", keyindex = 1, keyname = "Voltage", keyunit = "v", keyminmax = 1, color = colorTable['voltage'], pen = SOLID, graph = true},
    {name = "current", keyindex = 2, keyname = "Current", keyunit = "A", keyminmax = 1, color = colorTable['current'], pen = SOLID, graph = true},
    {name = "rpm", keyindex = 3, keyname = "Headspeed", keyunit = "rpm", keyminmax = 1, keyfloor = true, color = colorTable['rpm'], pen = SOLID, graph = true},
    {name = "temp_esc", keyindex = 4, keyname = "Esc. Temperature", keyunit = "°", keyminmax = 1, color = colorTable['temp_esc'], pen = SOLID, graph = true},
    {name = "throttle_percent", keyindex = 5, keyname = "Throttle %", keyunit = "%", keyminmax = 1, color = colorTable['throttle_percent'], pen = SOLID, graph = true}
}

local log_queue = {}
local logDirChecked = false
local cachedSensors = {} -- cache for sensor sources
local armSource = nil    -- separate cache for armflags sensor

local function generateLogFilename()
    local craftName = rfsuite.utils.sanitize_filename(rfsuite.session.craftName)
    local modelName = (craftName and craftName ~= "") and craftName or model.name()
    modelName = string.gsub(modelName, "%s+", "_"):gsub("%W", "_")
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local uniquePart = math.floor(os.clock() * 1000)
    return modelName .. "_" .. timestamp .. "_" .. uniquePart .. ".csv"
end

local function checkLogdirExists()
    local logdir = "telemetry"
    local logs_path = "logs/"
    if not rfsuite.utils.dir_exists(logdir, "./") then os.mkdir(logdir) end
    if not rfsuite.utils.dir_exists(logs_path, logdir) then os.mkdir(logs_path .. logdir) end
end

function logging.queueLog(msg)
    table.insert(log_queue, msg)
end

function logging.flushLogs(forceFlush)
    local max_lines = forceFlush or not rfsuite.session.telemetryState and 1 or 10
    if #log_queue > 0 and rfsuite.tasks.msp.mspQueue:isProcessed() and logFileName then
        local filePath = "logs/telemetry/" .. logFileName
        local f = io.open(filePath, 'a')
        for i = 1, math.min(#log_queue, max_lines) do
            io.write(f, table.remove(log_queue, 1) .. "\n")
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
        local src = cachedSensors[sensor.name]
        values[i] = src and src:value() or 0
    end
    return os.date("%Y-%m-%d_%H:%M:%S") .. ", " .. rfsuite.utils.joinTableItems(values, ", ")
end

function logging.getLogTable()
    return logTable
end

-- Sensor cache setup — runs once when telemetry becomes active
local function cacheSensorSources()
    cachedSensors = {}
    for _, sensor in ipairs(logTable) do
        cachedSensors[sensor.name] = rfsuite.tasks.telemetry.getSensorSource(sensor.name)
    end
    armSource = rfsuite.tasks.telemetry.getSensorSource("armflags")
end

-- Clear all cached sensors
local function clearSensorCache()
    cachedSensors = {}
    armSource = nil
end

function logging.wakeup()
    if not rfsuite.preferences.flightLog then return end

    if not logDirChecked then
        checkLogdirExists()
        logDirChecked = true
    end

    if not rfsuite.session.telemetryState then
        logFileName, logHeader = nil, nil
        logging.flushLogs(true)
        logdir = nil
        clearSensorCache()
        return
    end

    -- Cache sensors once when telemetry activates
    if not armSource then
        cacheSensorSources()
    end

    if armSource then
        local isArmed = armSource:value()

        if isArmed == 1 or isArmed == 3 then
            if not logFileName then logFileName = generateLogFilename() end
            if not logHeader then
                logHeader = logging.getLogHeader()
                logging.queueLog(logHeader)
            end

            if os.clock() - logRateLimit >= logInterval then
                logRateLimit = os.clock()
                logging.queueLog(logging.getLogLine())
            end

            logging.flushLogs()

        else
            logFileName, logHeader = nil, nil
            logging.flushLogs(true)
            logdir = nil
        end
    end
end

return logging
