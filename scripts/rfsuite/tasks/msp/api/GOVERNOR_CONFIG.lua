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
local API_NAME = "GOVERNOR_CONFIG" -- API name (must be same as filename)
local MSP_API_CMD_READ = 142 -- Command identifier for MSP Mixer Config Read
local MSP_API_CMD_WRITE = 143 -- Command identifier for saving Mixer Config Settings

-- define msp structure for reading and writing


local gov_modeTable ={[0] = "OFF", "PASSTHROUGH", "STANDARD", "MODE1", "MODE2"}

local MSP_API_STRUCTURE_READ_DATA = {
    {field = "gov_mode",                        type = "U8",  apiVersion = 12.06, simResponse = {3},    min = 0,  max = #gov_modeTable,   table = gov_modeTable},
    {field = "gov_startup_time",                type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0,  max = 600, unit = "s", default = 200, decimals = 1, scale = 10, help = "Time constant for slow startup, in seconds, measuring the time from zero to full headspeed."},
    {field = "gov_spoolup_time",                type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0,  max = 600, unit = "s", default = 100, decimals = 1, scale = 10, help = "Time constant for slow spoolup, in seconds, measuring the time from zero to full headspeed."},
    {field = "gov_tracking_time",               type = "U16", apiVersion = 12.06, simResponse = {20, 0},  min = 0,  max = 100, unit = "s", default = 10,  decimals = 1, scale = 10, help = "Time constant for headspeed changes, in seconds, measuring the time from zero to full headspeed."},
    {field = "gov_recovery_time",               type = "U16", apiVersion = 12.06, simResponse = {20, 0},  min = 0,  max = 100, unit = "s", default = 21,  decimals = 1, scale = 10, help = "Time constant for recovery spoolup, in seconds, measuring the time from zero to full headspeed."},
    {field = "gov_zero_throttle_timeout",       type = "U16", apiVersion = 12.06, simResponse = {30, 0}},
    {field = "gov_lost_headspeed_timeout",      type = "U16", apiVersion = 12.06, simResponse = {10, 0}},
    {field = "gov_autorotation_timeout",        type = "U16", apiVersion = 12.06, simResponse = {0, 0}},
    {field = "gov_autorotation_bailout_time",   type = "U16", apiVersion = 12.06, simResponse = {0, 0}},
    {field = "gov_autorotation_min_entry_time", type = "U16", apiVersion = 12.06, simResponse = {50, 0}},
    {field = "gov_handover_throttle",           type = "U8",  apiVersion = 12.06, simResponse = {10},   min = 10, max = 50,  unit = "%", default = 20, help = "Governor activates above this %. Below this the input throttle is passed to the ESC."},
    {field = "gov_pwr_filter",                  type = "U8",  apiVersion = 12.06, simResponse = {5}},
    {field = "gov_rpm_filter",                  type = "U8",  apiVersion = 12.06, simResponse = {10}},
    {field = "gov_tta_filter",                  type = "U8",  apiVersion = 12.06, simResponse = {0}},
    {field = "gov_ff_filter",                   type = "U8",  apiVersion = 12.06, simResponse = {10}},
    {field = "gov_spoolup_min_throttle",        type = "U8",  apiVersion = 12.08, simResponse = {5},    min = 0,  max = 50,  unit = "%", default = 0, help = "Minimum throttle to use for slow spoolup, in percent. For electric motors the default is 5%, for nitro this should be set so the clutch starts to engage for a smooth spoolup 10-15%."},
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
        payload = suppliedPayload or rfsuite.bg.msp.api.buildWritePayload(API_NAME, payloadData,MSP_API_STRUCTURE_WRITE),
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
