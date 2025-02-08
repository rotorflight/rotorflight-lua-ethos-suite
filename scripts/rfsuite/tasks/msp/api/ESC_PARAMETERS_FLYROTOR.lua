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
local MSP_API_CMD_READ = 217 -- Command identifier 
local MSP_API_CMD_WRITE = 218 -- Command identifier 
local MSP_API_SIMULATOR_RESPONSE = {115, 0, 0, 0, 150, 231, 79, 190, 216, 78, 29, 169, 244, 1, 0, 0, 1, 0, 8, 0, 4, 76, 7, 148, 0, 6, 30, 125, 0, 10, 0, 3, 5, 1, 20, 0, 15, 0, 45, 0, 35, 0, 0, 1, 134, 160} -- Default simulator response
local MSP_SIGNATURE = 0x73
local MSP_HEADER_BYTES = 2

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ = {
    {field = "esc_signature", type = "U8"},                     -- 1
    {field = "esc_command", type = "U8"},                       -- 2

    -- Buffer containing esc info for decoding
    {field = "escinfo_1", type = "U8"},                         -- 3
    {field = "escinfo_2", type = "U8"},                         -- 4
    {field = "escinfo_3", type = "U8"},                         -- 5
    {field = "escinfo_4", type = "U8"},                         -- 6
    {field = "escinfo_5", type = "U8"},                         -- 7
    {field = "escinfo_6", type = "U8"},                         -- 8
    {field = "escinfo_7", type = "U8"},                         -- 9
    {field = "escinfo_8", type = "U8"},                         -- 10
    {field = "escinfo_9", type = "U8"},                         -- 11
    {field = "escinfo_10", type = "U8"},                        -- 12
    {field = "escinfo_11", type = "U8"},                        -- 13
    {field = "escinfo_12", type = "U8"},                        -- 14
    {field = "escinfo_13", type = "U8"},                        -- 15
    {field = "escinfo_14", type = "U8"},                        -- 16
    {field = "escinfo_15", type = "U8"},                        -- 17
    {field = "escinfo_16", type = "U8"},                        -- 18
    {field = "escinfo_17", type = "U8"},                        -- 19
    {field = "escinfo_18", type = "U8"},                        -- 20

    {field = "throttle_min", type = "U16", byteorder = "big"},  -- 21, 22
    {field = "throttle_max", type = "U16", byteorder = "big"},  -- 23, 24
    {field = "governor", type = "U8"},                          -- 25
    {field = "cell_count", type = "U8"},                        -- 26
    {field = "low_voltage_protection", type = "U8"},            -- 27
    {field = "temperature_protection", type = "U8"},            -- 28
    {field = "bec_voltage", type = "U8"},                       -- 29
    {field = "timing_angle", type = "U8"},                      -- 30
    {field = "motor_direction", type = "U8"},                   -- 31
    {field = "starting_torque", type = "U8"},                   -- 32
    {field = "response_speed", type = "U8"},                    -- 33
    {field = "buzzer_volume", type = "U8"},                     -- 34
    {field = "current_gain", type = "S8"},                      -- 35
    {field = "fan_control", type = "U8"},                       -- 36
    {field = "soft_start", type = "U8"},                        -- 37
    {field = "gov_p", type = "U16", byteorder = "big"},         -- 38, 39
    {field = "gov_i", type = "U16", byteorder = "big"},         -- 40, 41
    {field = "gov_d", type = "U16", byteorder = "big"},         -- 42, 43
    {field = "motor_erpm_max", type = "U24", byteorder = "big"} -- 44, 45, 46
}

-- Process msp structure to get version that works for api Version
local MSP_MIN_BYTES, MSP_API_STRUCTURE_READ = rfsuite.bg.msp.api.filterStructure(MSP_API_STRUCTURE_READ) 
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ -- Assuming identical structure for now

-- Check if the simulator response contains enough data
if #MSP_API_SIMULATOR_RESPONSE < MSP_MIN_BYTES then
    error("MSP_API_SIMULATOR_RESPONSE does not contain enough data to satisfy MSP_MIN_BYTES")
end

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
    setTimeout = setTimeout,
    mspSignature = MSP_SIGNATURE,
    mspHeaderBytes = MSP_HEADER_BYTES,
    simulatorResponse = MSP_API_SIMULATOR_RESPONSE
}
