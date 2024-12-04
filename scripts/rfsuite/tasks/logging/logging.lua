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

]]--

local arg = {...}
local config = arg[1]

local logging = {}
local logdir
local logInterval = 1  -- default is 1 second
local logFileName
local logRateLimit = os.clock()

-- List of sensors to log
local logTable = {
    "voltage", 
    "current", 
    "rpm", 
    "capacity", 
    "governor", 
    "tempESC", 
    "tempMCU", 
    "rssi", 
    "roll", 
    "pitch", 
    "yaw", 
    "collective"
}

-- Queue for log entries
local log_queue = {}

-- Sensor rate limit
local sensorRateLimit = os.clock()
local sensorRate = 2 -- seconds between sensor readings

-- Helper function to check if directory exists
local function dir_exists(base, name)
    base = base or "./"
    for _, v in pairs(system.listFiles(base)) do
        if v == name then
            return true
        end
    end
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
local function generateTimestampFilename()
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local uniquePart = math.floor(os.clock() * 1000) -- milliseconds
    return timestamp .. "_" .. uniquePart .. ".csv"
end

-- Update log directory based on model name
local function update_logdir()
    logdir = string.gsub(model.name(), "%s+", "_")
    logdir = string.gsub(logdir, "%W", "_")
    local logs_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and "logs/" or (config.suiteDir .. "/logs/")
    
    if not dir_exists(logs_path, logdir) then
        os.mkdir(logs_path .. logdir)
    end
end

-- Add log entry to queue
function logging.queueLog(msg)
    table.insert(log_queue, msg)
end

-- Write log entries to file
function logging.flushLogs(forceFlush)
    local max_lines_per_flush = forceFlush or not rfsuite.bg.telemetry.active() and 1 or 10

    if #log_queue > 0 and rfsuite.bg.msp.mspQueue:isProcessed() then
        local filePath = (rfsuite.utils.ethosVersionToMinor() < 16) and 
            (config.suiteDir .. "/logs/" .. logdir .. "/" .. logFileName) or 
            ("logs/" .. logdir .. "/" .. logFileName)
        
        local f = io.open(filePath, 'a')
        for i = 1, math.min(#log_queue, max_lines_per_flush) do
            io.write(f, table.remove(log_queue, 1) .. "\n")
        end
        io.close(f)
    end
end

-- Get header line for the CSV log file
function logging.getLogHeader()
    return "time, " .. rfsuite.utils.joinTableItems(logTable, ", ")
end

-- Generate log line for current sensor values
function logging.getLogLine()
    local lineValues = {}
    
    for i, v in ipairs(logTable) do
        local src = rfsuite.bg.telemetry.getSensorSource(v)
        lineValues[i] = src and src:value() or 0
    end

    return os.date("%Y-%m-%d_%H:%M:%S") .. ", " .. rfsuite.utils.joinTableItems(lineValues, ", ")
end

-- Main logging function
function logging.wakeup()
    if not config.flightLog then return end -- Abort if logging is disabled

    local armSource = rfsuite.bg.telemetry.getSensorSource("armflags")
    if armSource then
        local isArmed = armSource:value()

        -- If armed, start logging
        if isArmed == 1 or isArmed == 3 then
            if not logdir then update_logdir() end
            if not logFileName then logFileName = generateTimestampFilename() end
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
