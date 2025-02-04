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
 * read(servoCount): Initiates an MSP command to read data.
 * data(): Returns the parsed MSP data.
 * readComplete(): Checks if the read operation is complete.
 * readValue(fieldName): Returns the value of a specific field from MSP data.
 * readVersion(): Retrieves the API version in major.minor format.
 * setCompleteHandler(handlerFunction):  Set function to run on completion
 * setErrorHandler(handlerFunction): Set function to run on error   
]] --
-- Constants for MSP Commands
local MSP_API_CMD = 192 -- Command identifier for MSP Mixer Config
local MSP_API_SIMULATOR_RESPONSE = {209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209,
                                    7, 209, 7, 209, 7} -- Default simulator response
local MSP_MIN_BYTES = 10 -- quite likely to be higher

-- Define the MSP response data structure
local function genStructure(count)
    local structure = {}
    for i = 1, count do
        table.insert(structure,
                     {field = string.format("servo%d", i), type = "U16"})
    end
    return structure
end

-- Variable to store parsed MSP data
local mspData = nil

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()  

-- Function to initiate MSP read operation
local function read(servoCount)
    if servoCount == nil then servoCount = 4 end
    local message = {
        command = MSP_API_CMD, -- Specify the MSP command
        processReply = function(self, buf)
            -- Parse the MSP data using the defined structure
            local MSP_API_STRUCTURE = genStructure(servoCount)
            mspData = rfsuite.bg.msp.api.parseMSPData(buf, MSP_API_STRUCTURE)
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
