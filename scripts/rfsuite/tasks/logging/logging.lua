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

--[[
logTable: A table containing sensor data to be logged.
Each entry in the table is a table with the following fields:
- name: The name of the sensor (string).
- keyindex: The index of the sensor (number).
- keyname: The display name of the sensor (string).
- keyunit: The unit of measurement for the sensor (string).
- keyminmax: A flag indicating if min/max values should be tracked (number).
- keyfloor: (Optional) A flag indicating if the value should be floored (boolean).
- color: The color used for the sensor's graph (constant).
- pen: The pen style used for the sensor's graph (constant).
- graph: A flag indicating if the sensor should be graphed (boolean).
]]
local logTable = {
    {name = "voltage", keyindex = 1, keyname = "Voltage", keyunit = "v", keyminmax = 1, color = COLOR_RED, pen = SOLID, graph = true},
    {name = "current", keyindex = 2, keyname = "Current", keyunit = "A", keyminmax = 0, color = COLOR_ORANGE, pen = SOLID, graph = true},
    {name = "rpm", keyindex = 3, keyname = "Headspeed", keyunit = "rpm", keyminmax = 0, keyfloor = true, color = COLOR_GREEN, pen = SOLID, graph = true},
    {name = "tempESC", keyindex = 4, keyname = "Esc. Temperature", keyunit = "°", keyminmax = 1, color = COLOR_CYAN, pen = SOLID, graph = true},
    {name = "throttlePercentage", keyindex = 5, keyname = "Throttle %", keyunit = "%", keyminmax = 0, color = COLOR_YELLOW, pen = SOLID, graph = true}
}

-- Queue for log entries
local log_queue = {}

local logDirChecked = false

-- Sensor rate limit
local sensorRateLimit = os.clock()
local sensorRate = 1 -- seconds between sensor readings

--[[
    Generates a timestamped filename for logging purposes.

    The filename is constructed using the sanitized craft name or model name,
    followed by the current timestamp and a unique part based on the current clock time in milliseconds.

    Returns:
        string: The generated filename in the format "modelName_YYYY-MM-DD_HH-MM-SS_uniquePart.csv"
]]
local function generateLogFilename()
    local craftName = rfsuite.utils.sanitize_filename(rfsuite.session.craftName)
    local modelName = (craftName and craftName ~= "") and craftName or model.name()

    modelName = string.gsub(modelName, "%s+", "_")
    modelName = string.gsub(modelName, "%W", "_")
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local uniquePart = math.floor(os.clock() * 1000) -- milliseconds

    return modelName .. "_" .. timestamp .. "_" .. uniquePart .. ".csv"
end

--[[
    Function: checkLogdirExists
    Description: Checks if the required directories for logging exist and creates them if they do not.
    Directories:
        - "telemetry": The main directory for telemetry logs.
        - "logs/telemetry": The subdirectory within the main telemetry directory for storing logs.
    Dependencies: 
        - rfsuite.utils.dir_exists: Utility function to check if a directory exists.
        - os.mkdir: Function to create a new directory.
]]
local function checkLogdirExists()
    local logdir = "telemetry"
    local logs_path = "logs/" 

    if not rfsuite.utils.dir_exists(logs_dir, "./") then os.mkdir(logdir) end
    if not rfsuite.utils.dir_exists(logs_path, logdir) then os.mkdir(logs_path .. logdir) end
end

--[[
    Adds a message to the log queue.
    
    @param msg (string) The message to be logged.
]]
function logging.queueLog(msg)
    table.insert(log_queue, msg)
end


--[[
    Function: logging.flushLogs
    Description: Flushes the log queue to a file. If `forceFlush` is true or telemetry is inactive, it flushes one line per call; otherwise, it flushes up to ten lines.
    Parameters:
        forceFlush (boolean) - Optional. If true, forces a single line flush regardless of telemetry status.
    Returns: None
]]
function logging.flushLogs(forceFlush)
    local max_lines_per_flush = forceFlush or not rfsuite.tasks.telemetry.active() and 1 or 10

    if #log_queue > 0 and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local filePath = "logs/telemetry/" .. logFileName

        local f = io.open(filePath, 'a')
        for i = 1, math.min(#log_queue, max_lines_per_flush) do io.write(f, table.remove(log_queue, 1) .. "\n") end
        io.close(f)
    end
end

--[[
    Generates the log header string for the logging system.
    The header consists of a "time" column followed by the names of the columns in the logTable.
    @return string: The formatted log header string.
]]
function logging.getLogHeader()
    local tmpTable = {}
    for i, v in ipairs(logTable) do tmpTable[i] = v.name end
    return "time, " .. rfsuite.utils.joinTableItems(tmpTable, ", ")
end

--[[
    Function: logging.getLogLine
    Description: Generates a log line with the current date and time, followed by sensor values.
    Returns: A string containing the current date and time, followed by a comma-separated list of sensor values.
]]
function logging.getLogLine()
    local lineValues = {}

    for i, v in ipairs(logTable) do
        local src = rfsuite.tasks.telemetry.getSensorSource(v.name)
        lineValues[i] = src and src:value() or 0
    end

    return os.date("%Y-%m-%d_%H:%M:%S") .. ", " .. rfsuite.utils.joinTableItems(lineValues, ", ")
end

--[[
    Retrieves the log table.
    @return table logTable - The table containing log data.
]]
function logging.getLogTable()
    return logTable
end

--[[
    Function: logging.wakeup
    Description: Handles the logging process based on telemetry status and arming state.
    - If logging is disabled in preferences, the function returns immediately.
    - Checks if the log directory exists and sets the flag accordingly.
    - Clears logs if telemetry is not active.
    - If telemetry is active, checks the arming state from the "armflags" sensor.
    - If armed, starts logging by generating a log filename and header, and logs sensor data at defined intervals.
    - If disarmed, clears logs and resets relevant variables.
]]
function logging.wakeup()
    if not rfsuite.preferences.flightLog then return end -- Abort if logging is disabled

    if logDirChecked == false then
        checkLogdirExists()
        logDirChecked = true
    end


    -- If telemetry is not active, clear logs
    if rfsuite.tasks.telemetry.active() == false then
        logFileName = nil
        logHeader = nil
        logging.flushLogs(true)
        logdir = nil

        return
    end

    local armSource = rfsuite.tasks.telemetry.getSensorSource("armflags")
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
