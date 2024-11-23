--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]]--
--
local arg = {...}
local config = arg[1]

local logging = {}
local logdir
local logInterval = 1  -- default is 1
local logRateLimit
local logFileName
local logRateLimit = os.clock()

-- this is a list of all sensors that we will log when we arm and disarm
local logTable = {}
logTable[#logTable +1 ] = "voltage"
logTable[#logTable +1 ] = "current"
logTable[#logTable +1 ] = "rpm"
logTable[#logTable +1 ] = "capacity"
logTable[#logTable +1 ] = "governor"
logTable[#logTable +1 ] = "tempESC"
logTable[#logTable +1 ] = "tempMCU"
logTable[#logTable +1 ] = "rssi"
logTable[#logTable +1 ] = "roll"
logTable[#logTable +1 ] = "pitch"
logTable[#logTable +1 ] = "yaw"
logTable[#logTable +1 ] = "collective"

-- a queue that we iterate over to make sure we dont overload io.
local log_queue = {}

local sensorRateLimit = os.clock()
local sensorRate = 2 -- how fast can we call the rssi sensor

-- find out if folder exists
local function dir_exists(base,name)
        if base == nil then base = "./" end
        list = system.listFiles(base)       
        for i,v in pairs(list) do
                if v == name then
                        return true
                end
        end
        return false
end

-- find out if a file exists
local function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end

function generateTimestampFilename()
    -- Get the current date and time
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    -- Append a unique number using os.clock for further uniqueness if needed
    local uniquePart = math.floor(os.clock() * 1000) -- milliseconds resolution
    -- Combine them into a filesystem-friendly filename
    local filename = timestamp .. "_" .. uniquePart .. ".csv"
    return filename
end

function update_logdir()
    -- make log folder if it does not exist.
    -- this is based on the model name
    -- we restrict this to 1.6 and higher as this functionality does not exist.
    logdir = string.gsub(model.name(), "%s+", "_")
    logdir = string.gsub(logdir, "%W", "_")
    if rfsuite.utils.ethosVersionToMinor() >= 16 then
        if not dir_exists("logs/" ,logdir) then
            os.mkdir("logs/"..logdir)
        end    
    else
        if not dir_exists(config.suiteDir .. "/logs/" ,logdir) then
            os.mkdir(config.suiteDir .."/logs/"..logdir)
        end      
    end
end


function logging.queueLog(msg)
    if log_queue ~= nil then
            table.insert(log_queue, msg)
    end
end

function logging.flushLogs(x)

    local max_lines_per_flush 

    -- force flush of buffer on telem lost by sending x = true
    -- otherwise.. we write slower
    if not rfsuite.bg.telemetry.active() or x == true then
       max_lines_per_flush = 1
    else
       max_lines_per_flush = 10
    end        

    if #log_queue > 0 and rfsuite.bg.msp.mspQueue:isProcessed() then
    
        local f
            
        for i = 1, math.min(#log_queue, max_lines_per_flush) do
            
            if rfsuite.utils.ethosVersionToMinor() < 16 then
                f = io.open(config.suiteDir .. "/logs/"..logdir .. "/" .. logFileName, 'a')
            else
                f = io.open("logs/" .. logdir .. "/" .. logFileName, 'a')
            end
            io.write(f, table.remove(log_queue, 1) .. "\n")
            io.close(f)
       
        end
            
    end

end

function logging.getLogHeader()
    local lineValues = {}          
    for i,v in ipairs(logTable) do   
       lineValues[i] = v
    end
    local line = "time" .. ", "  .. rfsuite.utils.joinTableItems(lineValues, ", ")
    return line
end

function logging.getLogLine()

    local lineValues = {}
               
    for i,v in ipairs(logTable) do   
        local src = rfsuite.bg.telemetry.getSensorSource(v)
        local value = nil
        if src ~= nil then
            value = src:value()
        else
            value = 0
        end
       lineValues[i] = value
    end

    local line = os.date("%Y-%m-%d_%H:%M:%S") .. ", "  .. rfsuite.utils.joinTableItems(lineValues, ", ")

    return line

end

function logging.wakeup()

    source = system.getSource({category=CATEGORY_ANALOG, member=ANALOG_STICK_AILERON})



    -- quick abort if logging disabled
    if config.flightLog == false then
        return
    end

    -- detect if armed and log logging
    if rfsuite.bg.telemetry.active() then
        local armSource = rfsuite.bg.telemetry.getSensorSource("armflags")
        if armSource ~= nil then
            local isArmed = armSource:value()
            -- log stuff
            if (isArmed == 1 or isArmed == 3) then
                    if logdir == nil then
                        update_logdir()
                    end
                    if logFileName == nil then
                        logFileName = generateTimestampFilename()           
                    end    
                    if logHeader == nil then
                        logHeader = logging.getLogHeader()
                        logging.queueLog(logHeader)
                    end
                         
                    local now = os.clock()
                    if (os.clock() - logRateLimit) >= logInterval then
                        logRateLimit = now                  
                        logging.queueLog(logging.getLogLine())     
                    end
                logging.flushLogs()    
            else
                logFileName = nil
                logHeader = nil
                logging.flushLogs(true) 
                logdir = nil
            end
        end
        
    end

end

return logging
