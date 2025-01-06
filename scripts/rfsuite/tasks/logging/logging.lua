--[[

 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 
 * Note: Some icons have been sourced from https://www.flaticon.com/

]] --
local arg = {...}
local config = arg[1]

local logging = {}
local logInterval = 1 -- default is 1 second
local logFileName
local logRateLimit = os.clock()

-- List of sensors to log
local logTable = {{name = "voltage", keyindex = 1, keyname = "Voltage", keyunit = "v", keyminmax = 1, color = COLOR_RED, pen = SOLID, graph = true}, {name = "current", keyindex = 2, keyname = "Current", keyunit = "A", keyminmax = 0, color = COLOR_ORANGE, pen = SOLID, graph = true},
                  {name = "rpm", keyindex = 3, keyname = "Headspeed", keyunit = "rpm", keyminmax = 0, keyfloor = true, color = COLOR_GREEN, pen = SOLID, graph = true}, {name = "tempESC", keyindex = 4, keyname = "Esc. Temperature", keyunit = "°", keyminmax = 1, color = COLOR_CYAN, pen = SOLID, graph = true},
                  {name = "throttlePercentage", keyindex = 5, keyname = "Throttle %", keyunit = "%", keyminmax = 0, color = COLOR_YELLOW, pen = SOLID, graph = true}}

-- Queue for log entries
local log_queue = {}

local logDirChecked = false

-- Sensor rate limit
local sensorRateLimit = os.clock()
local sensorRate = 1 -- seconds between sensor readings

-- Helper function to check if directory exists
local function dir_exists(base, name)
    base = base or "./"
    for _, v in pairs(system.listFiles(base)) do if v == name then return true end end
    return false
end

-- Helper function to check if file exists
local function file_exists(name)
    local f = io.open(name, "r")
    if f then
        io.close(f)
        return true
    end
    return false
end

-- Generate a timestamped filename
local function generateLogFilename()
    local modelname = string.gsub(model.name(), "%s+", "_")
    modelname = string.gsub(modelname, "%W", "_")
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local uniquePart = math.floor(os.clock() * 1000) -- milliseconds
    return modelname .. "_" .. timestamp .. "_" .. uniquePart .. ".csv"
end

-- Update log directory based on model name
local function checkLogdirExists()
    local logdir = "telemetry"
    local logs_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and "logs/" or (config.suiteDir .. "/logs/")

    if not dir_exists(logs_path, logdir) then os.mkdir(logs_path .. logdir) end
end

-- Add log entry to queue
function logging.queueLog(msg)
    table.insert(log_queue, msg)
end

-- Write log entries to file
function logging.flushLogs(forceFlush)
    local max_lines_per_flush = forceFlush or not rfsuite.bg.telemetry.active() and 1 or 10

    if #log_queue > 0 and rfsuite.bg.msp.mspQueue:isProcessed() then
        local filePath = (rfsuite.utils.ethosVersionToMinor() < 16) and (config.suiteDir .. "/logs/telemetry/" .. logFileName) or ("logs/telemetry/" .. logFileName)

        local f = io.open(filePath, 'a')
        for i = 1, math.min(#log_queue, max_lines_per_flush) do io.write(f, table.remove(log_queue, 1) .. "\n") end
        io.close(f)
    end
end

-- Get header line for the CSV log file
function logging.getLogHeader()
    local tmpTable = {}
    for i, v in ipairs(logTable) do tmpTable[i] = v.name end
    return "time, " .. rfsuite.utils.joinTableItems(tmpTable, ", ")
end

-- Generate log line for current sensor values
function logging.getLogLine()
    local lineValues = {}

    for i, v in ipairs(logTable) do
        local src = rfsuite.bg.telemetry.getSensorSource(v.name)
        lineValues[i] = src and src:value() or 0
    end

    return os.date("%Y-%m-%d_%H:%M:%S") .. ", " .. rfsuite.utils.joinTableItems(lineValues, ", ")
end

-- get the log table
function logging.getLogTable()
    return logTable
end

-- Main logging function
function logging.wakeup()
    if not config.flightLog then return end -- Abort if logging is disabled

    if logDirChecked == false then
        checkLogdirExists()
        logDirChecked = true
    end

    local armSource = rfsuite.bg.telemetry.getSensorSource("armflags")
    if armSource then
        local isArmed = armSource:value()

        -- If armed, start logging
        if isArmed == 1 or isArmed == 3 then
            if not logFileName then logFileName = generateLogFilename() end
            if not logHeader then
                logHeader = logging.getLogHeader()
                logging.queueLog(logHeader)
            end

            -- Log sensor data at the defined interval
            if os.clock() - logRateLimit >= logInterval then
                logRateLimit = os.clock()
                logging.queueLog(logging.getLogLine())
            end
            logging.flushLogs()

            -- If disarmed, clear logs
        else
            logFileName = nil
            logHeader = nil
            logging.flushLogs(true)
            logdir = nil
        end
    end
end

return logging
