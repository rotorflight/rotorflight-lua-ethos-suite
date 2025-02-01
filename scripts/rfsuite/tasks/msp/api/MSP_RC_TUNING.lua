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
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note. Some icons have been sourced from https://www.flaticon.com/
]] --
--[[
 * API Reference Guide
 * -------------------
 * read(): Initiates an MSP command to read data.
 * data(): Returns the parsed MSP data.
 * readComplete(): Checks if the read operation is complete.
 * readValue(fieldName): Returns the value of a specific field from MSP data.
 * readVersion(): Retrieves the API version in major.minor format.
 * setCompleteHandler(handlerFunction):  Set function to run on completion
 * setErrorHandler(handlerFunction): Set function to run on error  
]] --
-- Constants for MSP Commands
local MSP_API_CMD = 111 -- Command identifier for MSP RC TUNING
local MSP_API_SIMULATOR_RESPONSE = {4, 18, 25, 32, 20, 0, 0, 18, 25, 32, 20, 0, 0, 32, 50, 45, 10, 0, 0, 56, 0, 56, 20, 0, 0} -- Default simulator response
local MSP_MIN_BYTES = 25

-- Define the MSP response data structure
-- parameters are:
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local MSP_API_STRUCTURE = {
    { field = "rates_type", type = "U8" },
    { field = "rcRates_1", type = "U8" },
    { field = "rcExpo_1", type = "U8" },
    { field = "rates_1", type = "U8" },
    { field = "response_time_1", type = "U8" },
    { field = "accel_limit_1", type = "U16" },
    { field = "rcRates_2", type = "U8" },
    { field = "rcExpo_2", type = "U8" },
    { field = "rates_2", type = "U8" },
    { field = "response_time_2", type = "U8" },
    { field = "accel_limit_2", type = "U16" },
    { field = "rcRates_3", type = "U8" },
    { field = "rcExpo_3", type = "U8" },
    { field = "rates_3", type = "U8" },
    { field = "response_time_3", type = "U8" },
    { field = "accel_limit_3", type = "U16" },
    { field = "rcRates_4", type = "U8" },
    { field = "rcExpo_4", type = "U8" },
    { field = "rates_4", type = "U8" },
    { field = "response_time_4", type = "U8" },
    { field = "accel_limit_4", type = "U16" }
}


-- Variable to store parsed MSP data
local mspData = nil

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()  

-- Additional data formating
local function processMSPData(buf, MSP_API_STRUCTURE)
    local data = {
        tables = {}  -- Create a nested table to hold indexed data
    }

    -- Ensure buffer is valid
    if not buf or type(buf) ~= "table" then
        return nil
    end

    local index = 1

    for i, field in ipairs(MSP_API_STRUCTURE) do
        local baseName, suffix = field.field:match("(.+)_(%d+)")
        local value = 0

        -- Determine data type and extract values from buffer
        if field.type == "U8" then
            value = buf[i] or 0
        elseif field.type == "U16" then
            value = (buf[i] or 0) + ((buf[i + 1] or 0) * 256)
        end

        if baseName and suffix then
            local keyIndex = tonumber(suffix) - 1  -- Convert suffix to zero-based index

            if not data.tables[keyIndex] then
                data.tables[keyIndex] = {}
            end

            data.tables[keyIndex][baseName] = value
        else
            -- Handle fields without a suffix (e.g., "rates_type")
            data[field.field] = value
        end
    end

    return data
end



-- Function to initiate MSP read operation
local function read()
    local message = {
        command = MSP_API_CMD, -- Specify the MSP command
        processReply = function(self, buf)
            -- Parse the MSP data using the defined structure
            mspData = rfsuite.bg.msp.api.parseMSPData(buf, MSP_API_STRUCTURE,processMSPData(buf, MSP_API_STRUCTURE))
            if #buf >= MSP_MIN_BYTES then
                local completeHandler = handlers.getCompleteHandler()
                if completeHandler then
                    completeHandler(self, buf)
                end
            end
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then 
                errorHandler(self, buf)
            end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE
    }
    -- Add the message to the processing queue
    rfsuite.bg.msp.mspQueue:add(message)
end

-- Function to return the parsed MSP data
local function data()
    return mspData
end

-- Function to check if the read operation is complete
local function readComplete()
    if mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES then
        return true
    end
    return false
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then
        return mspData['parsed'][fieldName]
    end
    return nil
end

-- Return the module's API functions
return {
    data = data,
    read = read,
    readComplete = readComplete,
    readVersion = readVersion,
    readValue = readValue,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler
}
