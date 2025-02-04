
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
local MSP_API_CMD = 112 -- Command identifier for MSP PILOT CONFIG
local MSP_API_SIMULATOR_RESPONSE = {70, 0, 225, 0, 90, 0, 120, 0, 100, 0, 200, 0, 70, 0, 120, 0, 100, 0, 125, 0, 83, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 25, 0} -- Default simulator response
local MSP_MIN_BYTES = 34

-- Grab some env vars
local arg = {...}
local apiFolder = arg[1]

-- Define the MSP response data structure
-- parameters are:
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local apiPath = _G.paramMspApiPath -- passed as tmp global as called via dofile()
local structure = assert(loadfile(apiPath .. "/structure.lua"))()
local MSP_API_STRUCTURE = structure.MSP_API_STRUCTURE

-- Variable to store parsed MSP data
local mspData = nil

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()  

local function extract_pid_data(buf)
    local data = {
        Roll = { P = 0, I = 0, D = 0, F = 0 },
        Pitch = { P = 0, I = 0, D = 0, F = 0 },
        Yaw = { P = 0, I = 0, D = 0, F = 0 }
    }

    -- Mapping rows to axis names
    local axis_map = { "Roll", "Pitch", "Yaw" }

    -- Define field mappings
    local fields = {
        { key = "P", vals = {1, 2}, row = 1 },
        { key = "P", vals = {9, 10}, row = 2 },
        { key = "P", vals = {17, 18}, row = 3 },

        { key = "I", vals = {3, 4}, row = 1 },
        { key = "I", vals = {11, 12}, row = 2 },
        { key = "I", vals = {19, 20}, row = 3 },

        { key = "D", vals = {5, 6}, row = 1 },
        { key = "D", vals = {13, 14}, row = 2 },
        { key = "D", vals = {21, 22}, row = 3 },

        { key = "F", vals = {7, 8}, row = 1 },
        { key = "F", vals = {15, 16}, row = 2 },
        { key = "F", vals = {23, 24}, row = 3 }
    }

    -- Iterate through fields and extract values
    for _, field in ipairs(fields) do
        local axis = axis_map[field.row]
        local value = buf[field.vals[1]] + (buf[field.vals[2]] * 256)  -- U16 Conversion
        data[axis][field.key] = value
    end

    return data
end

-- Function to initiate MSP read operation
local function read()
    local message = {
        command = MSP_API_CMD, -- Specify the MSP command
        processReply = function(self, buf)
            -- Parse the MSP data using the defined structure
            mspData = rfsuite.bg.msp.api.parseMSPData(buf, MSP_API_STRUCTURE,extract_pid_data(buf))
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
