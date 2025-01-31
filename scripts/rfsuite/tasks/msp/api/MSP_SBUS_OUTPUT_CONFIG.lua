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
local MSP_API_CMD = 152 -- Command identifier for MSP_SBUS_OUTPUT_CONFIG
local MSP_API_SIMULATOR_RESPONSE = {1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0,
24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 50} -- Default simulator response
local MSP_MIN_BYTES = 107


local function generateSbusApiStructure(numChannels)
    local structure = {}

    for i = 1, numChannels do
        table.insert(structure, { field = "Type_" .. i, type = "U8" })
        table.insert(structure, { field = "Index_" .. i, type = "U8" })
        table.insert(structure, { field = "RangeLow_" .. i, type = "S16" })
        table.insert(structure, { field = "RangeHigh_" .. i, type = "S16" })
    end

    return structure
end
-- Define the MSP response data structure
-- parameters are:
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local MSP_API_STRUCTURE = generateSbusApiStructure(16)

-- Variable to store parsed MSP data
local mspData = nil

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()  


-- Function to handle additional msp data processing
local function processMSPData(buf, MSP_API_STRUCTURE)
    local data = {}

    -- Ensure we have valid input data
    if not buf or type(buf) ~= "table" then
        return nil
    end

    -- Iterate through the MSP_API_STRUCTURE to extract relevant fields
    local index = 1
    for i = 1, #MSP_API_STRUCTURE, 4 do
        local channelData = {}

        -- Extract data based on structure definitions
        channelData["Type"] = buf[i] or 0
        channelData["Index"] = buf[i + 1] or 0
        channelData["RangeLow"] = (buf[i + 2] or 0) + ((buf[i + 3] or 0) * 256)
        channelData["RangeHigh"] = (buf[i + 4] or 0) + ((buf[i + 5] or 0) * 256)

        -- Store in ordered table
        data[index] = channelData
        index = index + 1
    end

    return data
end  

-- Function to initiate MSP read operation
local function read()
    local message = {
        command = MSP_API_CMD, -- Specify the MSP command
        processReply = function(self, buf)
            -- Parse the MSP data using the defined structure
            mspData = rfsuite.bg.msp.api.parseMSPData(buf, MSP_API_STRUCTURE,processMSPData(buf,MSP_API_STRUCTURE))
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
