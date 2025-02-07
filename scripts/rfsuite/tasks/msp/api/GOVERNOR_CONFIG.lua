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
local MSP_API_CMD_READ = 142 -- Command identifier for MSP Mixer Config Read
local MSP_API_CMD_WRITE = 143 -- Command identifier for saving Mixer Config Settings

local MSP_API_SIMULATOR_RESPONSE
local MSP_API_STRUCTURE_READ
local MSP_MIN_BYTES
if rfsuite.config.apiVersion >= 12.08 then
    MSP_API_SIMULATOR_RESPONSE = {3, 100, 0, 100, 0, 20, 0, 20, 0, 30, 0, 10, 0, 0, 0, 0, 0, 50, 0, 10, 5, 10, 0, 10, 5} -- Default simulator response
    MSP_API_STRUCTURE_READ = {
        {field = "gov_mode", type = "U8"},
        {field = "gov_startup_time", type = "U16"},
        {field = "gov_spoolup_time", type = "U16"},
        {field = "gov_tracking_time", type = "U16"},
        {field = "gov_recovery_time", type = "U16"},
        {field = "gov_zero_throttle_timeout", type = "U16"},
        {field = "gov_lost_headspeed_timeout", type = "U16"},
        {field = "gov_autorotation_timeout", type = "U16"},
        {field = "gov_autorotation_bailout_time", type = "U16"},
        {field = "gov_autorotation_min_entry_time", type = "U16"},
        {field = "gov_handover_throttle", type = "U8"},
        {field = "gov_pwr_filter", type = "U8"},
        {field = "gov_rpm_filter", type = "U8"},
        {field = "gov_tta_filter", type = "U8"},
        {field = "gov_ff_filter", type = "U8"},
        {field = "gov_spoolup_min_throttle", type = "U8"}
    }
    MSP_MIN_BYTES = 25    
else
    MSP_API_SIMULATOR_RESPONSE = {3, 100, 0, 100, 0, 20, 0, 20, 0, 30, 0, 10, 0, 0, 0, 0, 0, 50, 0, 10, 5, 10, 0, 10} -- Default simulator response
    MSP_API_STRUCTURE_READ = {
        {field = "gov_mode", type = "U8"},
        {field = "gov_startup_time", type = "U16"},
        {field = "gov_spoolup_time", type = "U16"},
        {field = "gov_tracking_time", type = "U16"},
        {field = "gov_recovery_time", type = "U16"},
        {field = "gov_zero_throttle_timeout", type = "U16"},
        {field = "gov_lost_headspeed_timeout", type = "U16"},
        {field = "gov_autorotation_timeout", type = "U16"},
        {field = "gov_autorotation_bailout_time", type = "U16"},
        {field = "gov_autorotation_min_entry_time", type = "U16"},
        {field = "gov_handover_throttle", type = "U8"},
        {field = "gov_pwr_filter", type = "U8"},
        {field = "gov_rpm_filter", type = "U8"},
        {field = "gov_tta_filter", type = "U8"},
        {field = "gov_ff_filter", type = "U8"},
    }
    MSP_MIN_BYTES = 24  
end


local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ -- Assuming identical structure for now

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
        print("No value set for MSP_API_CMD_READ")
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
        print("No value set for MSP_API_CMD_WRITE")
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
return {read = read, write = write, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data}
