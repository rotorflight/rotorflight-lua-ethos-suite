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
-- Constants for MSP Commands
local API_NAME = "RESCUE_PROFILE" -- API name (must be same as filename)
local MSP_API_CMD_READ = 146 -- Command identifier 
local MSP_API_CMD_WRITE = 147 -- Command identifier 

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rescue_mode",               type = "U8",  apiVersion = 12.06, simResponse = {1},   min = 0, max = 1,   default = 0,   table = {[0] = "OFF", "ON"}},
    {field = "rescue_flip_mode",          type = "U8",  apiVersion = 12.06, simResponse = {0},   min = 0, max = 1,   default = 0,   table = {[0] = "No flip", "Flip"}, help = "If rescue is activated while inverted, flip to upright - or remain inverted."},
    {field = "rescue_flip_gain",          type = "U8",  apiVersion = 12.06, simResponse = {200}, min = 5, max = 250, default = 50,  help = "Determine how agressively the heli flips during inverted rescue."},
    {field = "rescue_level_gain",         type = "U8",  apiVersion = 12.06, simResponse = {100}, min = 5, max = 250, default = 40,  help = "Determine how agressively the heli levels during rescue."},
    {field = "rescue_pull_up_time",       type = "U8",  apiVersion = 12.06, simResponse = {5},   min = 0, max = 250, default = 50,  unit = "s", decimals = 1, scale = 10, help = "When rescue is activated, helicopter will apply pull-up collective for this time period before moving to flip or climb stage."},
    {field = "rescue_climb_time",         type = "U8",  apiVersion = 12.06, simResponse = {3},   min = 0, max = 250, default = 200, unit = "s", decimals = 1, scale = 10, help = "Length of time the climb collective is applied before switching to hover."},
    {field = "rescue_flip_time",          type = "U8",  apiVersion = 12.06, simResponse = {10},  min = 0, max = 250, default = 100, unit = "s", decimals = 1, scale = 10, help = "If the helicopter is in rescue and is trying to flip to upright and does not within this time, rescue will be aborted."},
    {field = "rescue_exit_time",          type = "U8",  apiVersion = 12.06, simResponse = {5},   min = 0, max = 250, default = 50,  unit = "s", decimals = 1, scale = 10, help = "This limits rapid application of negative collective if the helicopter has rolled during rescue."},
    {field = "rescue_pull_up_collective", type = "U16", apiVersion = 12.06, simResponse = {182, 3}, min = 0, max = 1000, default = 650, unit = "%", scale = 10, help = "Collective value for pull-up climb."},
    {field = "rescue_climb_collective",   type = "U16", apiVersion = 12.06, simResponse = {188, 2}, min = 0, max = 1000, default = 450, unit = "%", scale = 10, help = "Collective value for rescue climb."},
    {field = "rescue_hover_collective",   type = "U16", apiVersion = 12.06, simResponse = {194, 1}, min = 0, max = 1000, default = 350, unit = "%", decimals = 1, scale = 10, help = "Collective value for hover."},
    {field = "rescue_hover_altitude",     type = "U16", apiVersion = 12.06, simResponse = {244, 1}},
    {field = "rescue_alt_p_gain",         type = "U16", apiVersion = 12.06, simResponse = {20, 0}},
    {field = "rescue_alt_i_gain",         type = "U16", apiVersion = 12.06, simResponse = {20, 0}},
    {field = "rescue_alt_d_gain",         type = "U16", apiVersion = 12.06, simResponse = {10, 0}},
    {field = "rescue_max_collective",     type = "U16", apiVersion = 12.06, simResponse = {232, 3}},
    {field = "rescue_max_setpoint_rate",  type = "U16", apiVersion = 12.06, simResponse = {44, 1}, min = 1, max = 1000, default = 250, unit = "°/s", help = "Limit rescue roll/pitch rate. Larger helicopters may need slower rotation rates."},
    {field = "rescue_max_setpoint_accel", type = "U16", apiVersion = 12.06, simResponse = {184, 11}, min = 1, max = 10000, default = 2000, unit = "°/^2", help = "Limit how fast the helicopter accelerates into a roll/pitch. Larger helicopters may need slower acceleration."}
}

-- Process structure in one pass
local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE =
    rfsuite.tasks.msp.api.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- set read structure
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

-- Variable to store parsed MSP data
local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.tasks.msp.api.createHandlers()

-- Variables to store optional the UUID and timeout for payload
local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

-- Function to initiate MSP read operation
local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_READ,
        processReply = function(self, buf)
            local structure = MSP_API_STRUCTURE_READ
            rfsuite.tasks.msp.api.parseMSPData(buf, structure, nil, nil, function(result)
                mspData = result
                if #buf >= MSP_MIN_BYTES then
                    local completeHandler = handlers.getCompleteHandler()
                    if completeHandler then completeHandler(self, buf) end
                end
            end)
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT  
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = suppliedPayload or rfsuite.tasks.msp.api.buildWritePayload(API_NAME, payloadData,MSP_API_STRUCTURE_WRITE),
        processReply = function(self, buf)
            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then completeHandler(self, buf) end
            mspWriteComplete = true
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = {},
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT  
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    payloadData[fieldName] = value
end

-- Function to check if the read operation is complete
local function readComplete()
    return mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES
end

-- Function to check if the write operation is complete
local function writeComplete()
    return mspWriteComplete
end

-- Function to reset the write completion status
local function resetWriteStatus()
    mspWriteComplete = false
end

-- Function to return the parsed MSP data
local function data()
    return mspData
end

-- set the UUID for the payload
local function setUUID(uuid)
    MSP_API_UUID = uuid
end

-- set the timeout for the payload
local function setTimeout(timeout)
    MSP_API_MSG_TIMEOUT = timeout
end

-- Return the module's API functions
return {
    read = read,
    write = write,
    readComplete = readComplete,
    writeComplete = writeComplete,
    readValue = readValue,
    setValue = setValue,
    resetWriteStatus = resetWriteStatus,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}
