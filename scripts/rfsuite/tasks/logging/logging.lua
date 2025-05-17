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
local govSource = nil    -- separate cache for governor sensor

local function generateLogFilename()
    local craftName = rfsuite.utils.sanitize_filename(rfsuite.session.craftName)
    local modelName = (craftName and craftName ~= "") and craftName or model.name()
    modelName = string.gsub(modelName, "%s+", "_"):gsub("%W", "_")
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local uniquePart = math.floor(os.clock() * 1000)
    return modelName .. "_" .. timestamp .. "_" .. uniquePart .. ".csv"
end

local function checkLogdirExists()
        os.mkdir("LOGS:")
        os.mkdir("LOGS:/rfsuite")
        os.mkdir("LOGS:/rfsuite/telemetry")
end

function logging.queueLog(msg)
    table.insert(log_queue, msg)
end

function logging.writeLogs(forcewrite)
    local max_lines = forcewrite and #log_queue or 10
    if #log_queue > 0 and logFileName then
        rfsuite.utils.log("Write " .. #log_queue .. " lines to " .. logFileName,"info")
        local filePath = "LOGS:rfsuite/telemetry/" .. logFileName
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
    govSource = rfsuite.tasks.telemetry.getSensorSource("governor")
end

-- Clear all cached sensors
local function clearSensorCache()
    cachedSensors = {}
    armSource = nil
    govSource = nil
end

function logging.flushLogs()
    if logFileName or logHeader then
        rfsuite.utils.log("Flushing logs - ".. logFileName,"info")
        logFileName, logHeader = nil, nil
        logging.writeLogs(true)
        logdir = nil
    end    
end

function logging.reset()
    clearSensorCache()
    cacheSensorSources()
end

function logging.wakeup()

    if not logDirChecked then
        checkLogdirExists()
        logDirChecked = true
    end

    --if not rfsuite.session.telemetryState then
    if not rfsuite.tasks.telemetry.active() then
        logging.flushLogs()
        clearSensorCache()
        cacheSensorSources()
        return
    end

    -- Cache sensors once when telemetry activates
    if not armSource then
        cacheSensorSources()
    end

    if armSource then

        if armSource and not govSource then

            local isArmed = armSource:value()

            if isArmed == 1 or isArmed == 3 then
                if not logFileName then 
                    logFileName = generateLogFilename() 
                    rfsuite.utils.log("Logging triggered by arm state - " .. logFileName,"info")
                    rfsuite.utils.log("Armed value - " .. isArmed  ,"info")
                end
                if not logHeader then
                    logHeader = logging.getLogHeader()
                    logging.queueLog(logHeader)
                end

                if os.clock() - logRateLimit >= logInterval then
                    logRateLimit = os.clock()
                    logging.queueLog(logging.getLogLine())
                
                    -- only write if queue has built up a bit
                    if #log_queue >= 5 then
                        logging.writeLogs()
                    end
                end

            else
                logging.flushLogs()    
            end
        elseif armSource and govSource then

            local isArmed = armSource:value()
            local governor = govSource:value()

            if isArmed == nil or governor == nil then
                logging.flushLogs()
            elseif isArmed == 1 or isArmed == 3 and governor > 0 and governor < 100 then
                if not logFileName then 
                    logFileName = generateLogFilename() 
                    rfsuite.utils.log("Logging triggered by governor state - " .. logFileName ,"info")
                    rfsuite.utils.log("Governor value - " .. governor ,"info")
                    rfsuite.utils.log("Armed value - " .. isArmed  ,"info")
                end
                if not logHeader then
                    logHeader = logging.getLogHeader()
                    logging.queueLog(logHeader)
                end

                if os.clock() - logRateLimit >= logInterval then
                    logRateLimit = os.clock()
                    logging.queueLog(logging.getLogLine())
                
                    -- only write if queue has built up a bit
                    if #log_queue >= 5 then
                        logging.writeLogs()
                    end
                end
            else    
                logging.flushLogs()
            end
        end   

        

    end
end

return logging
