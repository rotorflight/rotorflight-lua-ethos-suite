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
local MSP_API_CMD_READ = 131 -- Command identifier 
local MSP_API_CMD_WRITE = 222 -- Command identifier 
local MSP_API_SIMULATOR_RESPONSE = {
    45, 4, 208, 7, 232, 3, 1, 6, 0, 0,
    250, 0, 1, 6, 4, 2, 1, 8, 7, 7,
    8, 20, 0, 50, 0, 9, 0, 30, 0
} -- Default simulator response
local MSP_MIN_BYTES = 29

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ = {
    {field = "minthrottle", type = "U16"},
    {field = "maxthrottle", type = "U16"},
    {field = "mincommand", type = "U16"},
    {field = "motor_count_blheli", type = "U8"},             -- compat: BLHeliSuite
    {field = "motor_pole_count_blheli", type = "U8"},      -- compat: BLHeliSuite
    {field = "use_dshot_telemetry", type = "U8"},
    {field = "motor_pwm_protocol", type = "U8"},
    {field = "motor_pwm_rate", type = "U16"},
    {field = "use_unsynced_pwm", type = "U8"},
    {field = "motor_pole_count_0", type = "U8"},
    {field = "motor_pole_count_1", type = "U8"},
    {field = "motor_pole_count_2", type = "U8"},
    {field = "motor_pole_count_3", type = "U8"},
    {field = "motor_rpm_lpf_0", type = "U8"},
    {field = "motor_rpm_lpf_1", type = "U8"},
    {field = "motor_rpm_lpf_2", type = "U8"},
    {field = "motor_rpm_lpf_3", type = "U8"},
    {field = "main_rotor_gear_ratio_0", type = "U16"},
    {field = "main_rotor_gear_ratio_1", type = "U16"},
    {field = "tail_rotor_gear_ratio_0", type = "U16"},
    {field = "tail_rotor_gear_ratio_1", type = "U16"}
}

local MSP_API_STRUCTURE_WRITE = {
    {field = "minthrottle", type = "U16"},
    {field = "maxthrottle", type = "U16"},
    {field = "mincommand", type = "U16"},
 -- {field = "motor_count_blheli", type = "U8"},           -- compat: BLHeliSuite for no good reason this is missing from the write structure
    {field = "motor_pole_count_blheli", type = "U8"},      -- compat: BLHeliSuite
    {field = "use_dshot_telemetry", type = "U8"},
    {field = "motor_pwm_protocol", type = "U8"},
    {field = "motor_pwm_rate", type = "U16"},
    {field = "use_unsynced_pwm", type = "U8"},
    {field = "motor_pole_count_0", type = "U8"},
    {field = "motor_pole_count_1", type = "U8"},
    {field = "motor_pole_count_2", type = "U8"},
    {field = "motor_pole_count_3", type = "U8"},
    {field = "motor_rpm_lpf_0", type = "U8"},
    {field = "motor_rpm_lpf_1", type = "U8"},
    {field = "motor_rpm_lpf_2", type = "U8"},
    {field = "motor_rpm_lpf_3", type = "U8"},
    {field = "main_rotor_gear_ratio_0", type = "U16"},
    {field = "main_rotor_gear_ratio_1", type = "U16"},
    {field = "tail_rotor_gear_ratio_0", type = "U16"},
    {field = "tail_rotor_gear_ratio_1", type = "U16"}
}

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

-- helper function to shift payload position when writing with a supplied payload
local function shiftSuppliedPayload(payload)
    local newPayload = {}
    for i, v in ipairs(payload) do
        if i > 6 then
            newPayload[i] = payload[i + 1]
        else
            newPayload[i] = payload[i]
        end

    end
    return newPayload
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        print("No value set for MSP_API_CMD_WRITE")
        return
    end

    -- If suppliedPayload is not nil, shift the payload as this write api does not honour the order of the read command
    if suppliedPayload ~=nil then
        suppliedPayload = shiftSuppliedPayload(suppliedPayload)
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
return {read = read, write = write, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
