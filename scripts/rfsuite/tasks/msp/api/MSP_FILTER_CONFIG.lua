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
local MSP_API_CMD = 92 -- Command identifier for MSP_FILTER_CONFIG
local MSP_API_SIMULATOR_RESPONSE = {0, 1, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                                    0, 0, 0, 0, 0, 2, 25, 25, 0, 245, 0} -- Default simulator response
local MSP_MIN_BYTES = 25

-- Define the MSP response data structure
-- parameters are:
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local MSP_API_STRUCTURE = {{field = "gyro_hardware_lpf", type = "U8"},
                           {field = "gyro_lpf1_type", type = "U8"},
                           {field = "gyro_lpf1_static_hz", type = "U16"},
                           {field = "gyro_lpf2_type", type = "U8"},
                           {field = "gyro_lpf2_static_hz", type = "U16"},
                           {field = "gyro_soft_notch_hz_1", type = "U16"},
                           {field = "gyro_soft_notch_cutoff_1", type = "U16"},
                           {field = "gyro_soft_notch_hz_2", type = "U16"},
                           {field = "gyro_soft_notch_cutoff_2", type = "U16"},
                           {field = "gyro_lpf1_dyn_min_hz", type = "U16"},
                           {field = "gyro_lpf1_dyn_max_hz", type = "U16"}}

-- Variable to store parsed MSP data
local mspData = nil

-- Variable to store the custom complete handler
local customCompleteHandler = nil

-- Function to set the Complete handler
local function setCompleteHandler(handlerFunction)
    if type(handlerFunction) == "function" then
        customCompleteHandler = handlerFunction
    else
        error("setCompleteHandler expects a function")
    end
end

-- Variable to store the custom error handler
local customErrorHandler = nil

-- Function to set the error handler
local function setErrorHandler(handlerFunction)
    if type(handlerFunction) == "function" then
        customErrorHandler = handlerFunction
    else
        error("setErrorHandler expects a function")
    end
end

-- parse data
local function parseMSPData(buf, structure)
    -- Ensure buffer length matches expected data structure
    if #buf < #structure then return nil end

    local parsedData = {}
    local offset = 1 -- Maintain a strict offset tracking

    for _, field in ipairs(structure) do
        local byteorder = field.byteorder or "little" -- Default to little-endian

        if field.type == "U8" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU8(buf,
                                                                      offset)
            offset = offset + 1
        elseif field.type == "S8" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readS8(buf,
                                                                      offset)
            offset = offset + 1
        elseif field.type == "U16" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU16(buf,
                                                                       offset,
                                                                       byteorder)
            offset = offset + 2
        elseif field.type == "S16" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readS16(buf,
                                                                       offset,
                                                                       byteorder)
            offset = offset + 2
        elseif field.type == "U24" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU24(buf,
                                                                       offset,
                                                                       byteorder)
            offset = offset + 3
        elseif field.type == "S24" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readS24(buf,
                                                                       offset,
                                                                       byteorder)
            offset = offset + 3
        elseif field.type == "U32" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU32(buf,
                                                                       offset,
                                                                       byteorder)
            offset = offset + 4
        elseif field.type == "S32" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readS32(buf,
                                                                       offset,
                                                                       byteorder)
            offset = offset + 4
        else
            return nil
        end
    end

    -- prepare data for return
    local data = {}
    data['parsed'] = parsedData
    data['buffer'] = buf

    return data
end

-- Function to initiate MSP read operation
local function read()
    local message = {
        command = MSP_API_CMD, -- Specify the MSP command
        processReply = function(self, buf)
            -- Parse the MSP data using the defined structure
            mspData = parseMSPData(buf, MSP_API_STRUCTURE)
            if #buf >= MSP_MIN_BYTES then
                if customCompleteHandler then
                    customCompleteHandler(self, buf)
                end
            end
        end,
        errorHandler = function(self, buf)
            if customErrorHandler then customErrorHandler(self, buf) end
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
    setCompleteHandler = setCompleteHandler,
    setErrorHandler = setErrorHandler
}
