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
local MSP_API_SIMULATOR_RESPONSE = {83, 128, 84, 114, 105, 98, 117, 110, 117, 115, 32, 69, 83, 67, 45, 54, 83, 45, 56, 48, 65, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 0, 3, 0, 3, 0, 1, 0, 3, 0, 136, 19, 22, 3, 16, 39, 64, 31, 136, 19, 0, 0, 1, 0, 7, 2, 0, 6, 63, 0, 160, 15, 64, 31, 208, 7, 100, 0, 0, 0, 200, 0, 0, 0, 1, 0, 0, 0, 200, 250, 0, 0} -- Default simulator response
local MSP_MIN_BYTES = 84
local MSP_SIGNATURE = 0x53
local MSP_HEADER_BYTES = 2

local MSP_API_STRUCTURE_READ = {
    {field = "esc_signature", type = "U8"},        -- 1
    {field = "esc_command", type = "U8"},          -- 2

    {field = "escinfo_1", type = "U8"},            -- 3
    {field = "escinfo_2", type = "U8"},            -- 4
    {field = "escinfo_3", type = "U8"},            -- 5
    {field = "escinfo_4", type = "U8"},            -- 6
    {field = "escinfo_5", type = "U8"},            -- 7
    {field = "escinfo_6", type = "U8"},            -- 8
    {field = "escinfo_7", type = "U8"},            -- 9
    {field = "escinfo_8", type = "U8"},            -- 10
    {field = "escinfo_9", type = "U8"},            -- 11
    {field = "escinfo_10", type = "U8"},           -- 12
    {field = "escinfo_11", type = "U8"},           -- 13
    {field = "escinfo_12", type = "U8"},           -- 14
    {field = "escinfo_13", type = "U8"},           -- 15
    {field = "escinfo_14", type = "U8"},           -- 16
    {field = "escinfo_15", type = "U8"},           -- 17
    {field = "escinfo_16", type = "U8"},           -- 18
    {field = "escinfo_17", type = "U8"},           -- 19
    {field = "escinfo_18", type = "U8"},           -- 20
    {field = "escinfo_19", type = "U8"},           -- 21
    {field = "escinfo_20", type = "U8"},           -- 22
    {field = "escinfo_21", type = "U8"},           -- 23
    {field = "escinfo_22", type = "U8"},           -- 24
    {field = "escinfo_23", type = "U8"},           -- 25
    {field = "escinfo_24", type = "U8"},           -- 26
    {field = "escinfo_25", type = "U8"},           -- 27
    {field = "escinfo_26", type = "U8"},           -- 28
    {field = "escinfo_27", type = "U8"},           -- 29
    {field = "escinfo_28", type = "U8"},           -- 30
    {field = "escinfo_29", type = "U8"},           -- 31
    {field = "escinfo_30", type = "U8"},           -- 32
    {field = "escinfo_31", type = "U8"},           -- 33
    {field = "escinfo_32", type = "U8"},           -- 34

    {field = "esc_mode", type = "U16"},            -- 35, 36
    {field = "bec_voltage", type = "U16"},         -- 37, 38
    {field = "rotation", type = "U16"},            -- 39, 40

    -- no idea what this is for
    {field = "dummy_0", type = "U16"},             -- 41, 42

    {field = "protection_delay", type = "U16"},    -- 43, 44
    {field = "min_voltage", type = "U16"},         -- 45, 46
    {field = "max_temperature", type = "U16"},     -- 47, 48
    {field = "max_current", type = "U16"},         -- 49, 50
    {field = "cutoff_handling", type = "U16"},     -- 51, 52
    {field = "max_used", type = "U16"},            -- 53, 54
    {field = "motor_startup_sound", type = "U16"}, -- 55, 56

    -- no idea what these are for
    {field = "paddding_1", type = "U16"},          -- 57, 58
    {field = "paddding_2", type = "U16"},          -- 59, 60
    {field = "paddding_3", type = "U16"},          -- 61, 62

    {field = "soft_start_time", type = "U16"},     -- 63, 64
    {field = "runup_time", type = "U16"},          -- 65, 66
    {field = "bailout", type = "U16"},             -- 67, 68
    {field = "gov_proportional", type = "U32"},    -- 69, 70, 71, 72
    {field = "gov_integral", type = "U32"},        -- 73, 74, 75, 76
}

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
