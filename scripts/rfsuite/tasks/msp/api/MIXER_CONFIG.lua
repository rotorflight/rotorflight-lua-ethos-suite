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
local MSP_API_CMD_READ = 42 -- Command identifier for MSP Mixer Config Read
local MSP_API_CMD_WRITE = 43 -- Command identifier for saving Mixer Config Settings

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "main_rotor_dir",                 type = "U8",  apiVersion = 12.06, simResponse = {0}},
    {field = "tail_rotor_mode",                type = "U8",  apiVersion = 12.06, simResponse = {1}},
    {field = "tail_motor_idle",                type = "U8",  apiVersion = 12.06, simResponse = {0},  default = 0, unit = "%", min = 0,  max = 250, decimals = 1, scale = 10, help = "Minimum throttle signal sent to the tail motor. This should be set just high enough that the motor does not stop."},
    {field = "tail_center_trim",               type = "U16", apiVersion = 12.06, simResponse = {0, 0}, default = 0,  max = 500, decimals = 1, scale = 10, help ="Sets tail rotor trim for 0 yaw for variable pitch, or tail motor throttle for 0 yaw for motorized."},
    {field = "swash_type",                     type = "U8",  apiVersion = 12.06, simResponse = {0}},
    {field = "swash_ring",                     type = "U8",  apiVersion = 12.06, simResponse = {2}},
    {field = "swash_phase",                    type = "U16", apiVersion = 12.06, simResponse = {100, 0}, default = 0, max = 1800, decimals = 1, scale = 10, help = "Phase offset for the swashplate controls."},
    {field = "swash_pitch_limit",              type = "U16", apiVersion = 12.06, simResponse = {0, 0},   default = 0, min = 0, max = 3000, decimals = 1, scale = 83.33333333333333, step = 1, help = "Maximum amount of combined cyclic and collective blade pitch."},
    {field = "swash_trim_0",                   type = "U16", apiVersion = 12.06, simResponse = {0, 0}, default = 0, max = 1000, decimals = 1, scale = 10, help ="Swash trim to level the swash plate when using fixed links."},
    {field = "swash_trim_1",                   type = "U16", apiVersion = 12.06, simResponse = {0, 0}, default = 0,  max = 1000, decimals = 1, scale = 10, help ="Swash trim to level the swash plate when using fixed links."},
    {field = "swash_trim_2",                   type = "U16", apiVersion = 12.06, simResponse = {0, 0},default = 0,  max = 1000, decimals = 1, scale = 10, help ="Swash trim to level the swash plate when using fixed links."},
    {field = "swash_tta_precomp",              type = "U8",  apiVersion = 12.06, simResponse = {0},  default = 0, min = 0, max = 250, help = "Mixer precomp for 0 yaw."},
    {field = "swash_geo_correction",           type = "U8",  apiVersion = 12.07, simResponse = {0},  default = 0, max = 125, decimals = 1, scale = 5, step = 2, help = "Adjust if there is too much negative collective or too much positive collective."},
    {field = "collective_tilt_correction_pos", type = "S8",  apiVersion = 12.08, simResponse = {0},  default = 0, max = 100, help = "Adjust the collective tilt correction scaling for postive collective pitch."},
    {field = "collective_tilt_correction_neg", type = "S8",  apiVersion = 12.08, simResponse = {10}, default = 10, max = 100, help = "Adjust the collective tilt correction scaling for negative collective pitch."},
}

-- filter the structure to remove any params not supported by the running api version
local MSP_API_STRUCTURE_READ = rfsuite.bg.msp.api.filterByApiVersion(MSP_API_STRUCTURE_READ_DATA)

-- calculate the min bytes value from the structure
local MSP_MIN_BYTES = rfsuite.bg.msp.api.calculateMinBytes(MSP_API_STRUCTURE_READ)

-- set read structure
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

-- generate a simulatorResponse from the read structure
local MSP_API_SIMULATOR_RESPONSE = rfsuite.bg.msp.api.buildSimResponse(MSP_API_STRUCTURE_READ)

-- Variable to store parsed MSP data
local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()

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
            mspData = rfsuite.bg.msp.api.parseMSPData(buf, MSP_API_STRUCTURE_READ)
            if #buf >= MSP_MIN_BYTES then
                local completeHandler = handlers.getCompleteHandler()
                if completeHandler then completeHandler(self, buf) end
            end
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT  
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = suppliedPayload or payloadData,
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
    rfsuite.bg.msp.mspQueue:add(message)
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    for _, field in ipairs(MSP_API_STRUCTURE_WRITE) do
        if field.field == fieldName then
            payloadData[fieldName] = value
            return true
        end
    end
    error("Invalid field name: " .. fieldName)
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
