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
local MSP_API_CMD = 146 -- Command identifier for MSP RESCUE PROFILE
local MSP_API_SIMULATOR_RESPONSE = {1, 0, 200, 100, 5, 3, 10, 5, 182, 3, 188, 2, 194, 1, 244, 1, 20, 0, 20, 0, 10, 0, 232, 3, 44, 1, 184, 11} -- Default simulator response
local MSP_MIN_BYTES = 28

-- Define the MSP response data structure
-- parameters are:
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local MSP_API_STRUCTURE = {
    { field = "rescue_mode", type = "U8" },
    { field = "rescue_flip_mode", type = "U8" },
    { field = "rescue_flip_gain", type = "U8" },
    { field = "rescue_level_gain", type = "U8" },
    { field = "rescue_pull_up_time", type = "U8" },
    { field = "rescue_climb_time", type = "U8" },
    { field = "rescue_flip_time", type = "U8" },
    { field = "rescue_exit_time", type = "U8" },

    { field = "rescue_pull_up_collective", type = "U16" },
    { field = "rescue_climb_collective", type = "U16" },
    { field = "rescue_hover_collective", type = "U16" },
    { field = "rescue_hover_altitude", type = "U16" },
    { field = "rescue_alt_p_gain", type = "U16" },
    { field = "rescue_alt_i_gain", type = "U16" },
    { field = "rescue_alt_d_gain", type = "U16" },
    { field = "rescue_max_collective", type = "U16" },
    { field = "rescue_max_setpoint_rate", type = "U16" },
    { field = "rescue_max_setpoint_accel", type = "U16" },
}

-- Variable to store parsed MSP data
local mspData = nil

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()  


-- Stub Function for additional processing of retured data
local function processMSPData(buf, MSP_API_STRUCTURE)
    local data = {}
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
