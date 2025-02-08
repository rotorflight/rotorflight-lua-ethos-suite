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
local MSP_API_SIMULATOR_RESPONSE = {165, 0, 32, 0, 3, 0, 55, 0, 0, 0, 0, 0, 4, 0, 3, 0, 1, 0, 1, 0, 2, 0, 3, 0, 80, 3, 131, 148, 1, 0, 30, 170, 0, 0, 3, 0, 86, 4, 22, 3, 163, 15, 1, 0, 2, 0, 2, 0, 20, 0, 20, 0, 0, 0, 0, 0, 2, 19, 2, 0, 20, 0, 22, 0, 0, 0} -- Default simulator response
local MSP_MIN_BYTES = 60
local MSP_SIGNATURE = 0xA5
local MSP_HEADER_BYTES = 2

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ = {
    {field = "esc_signature", type = "U8"},         -- 1
    {field = "esc_command", type = "U8"},           -- 2
    {field = "esc_model", type = "U8"},             -- 3
    {field = "esc_version", type = "U8"},           -- 4
    {field = "governor", type = "U16"},             -- 5-6 (ESC Mode)
    {field = "lv_bec_voltage", type = "U16"},       -- 7-8 (BEC Voltage)
    {field = "timing", type = "U16"},               -- 9-10 (Motor Timing)
    {field = "acceleration", type = "U16"},         -- 11-12 (Potential Startup Response)
    {field = "gov_p", type = "U16"},                -- 13-14 (P-Gain)
    {field = "gov_i", type = "U16"},                -- 15-16 (I-Gain)
    {field = "throttle_response", type = "U16"},    -- 17-18 (Throttle Response)
    {field = "auto_restart_time", type = "U16"},    -- 19-20 (Cutoff Handling)
    {field = "cell_cutoff", type = "U16"},          -- 21-22 (Cutoff Cell Voltage)
    {field = "active_freewheel", type = "U16"},     -- 23-24 (Active Freewheel)

    -- unknown data
    {field = "padding_1", type = "U16"},            -- 25-26 (Padding)
    {field = "padding_2", type = "U16"},            -- 27-28 (Padding)
    {field = "padding_3", type = "U16"},            -- 29-30 (Padding)
    {field = "padding_4", type = "U16"},            -- 31-32 (Padding)
    {field = "padding_5", type = "U16"},            -- 33-34 (Padding)
    {field = "padding_6", type = "U16"},            -- 35-36 (Padding)


    {field = "stick_zero_us", type = "U16"},        -- 37-38 (Stick Zero (us))
    {field = "stick_range_us", type = "U16"},       -- 39-40 (Stick Range (us))
    {field = "padding_7", type = "U16"},            -- 41-42 (Padding)
    {field = "motor_poll_pairs", type = "U16"},     -- 43-44 (Motor Pole Pairs)
    {field = "pinion_teeth", type = "U16"},         -- 45-46 (Pinion Teeth)
    {field = "main_teeth", type = "U16"},           -- 47-48 (Main Teeth)
    {field = "min_start_power", type = "U16"},      -- 49-50 (Min Start Power)
    {field = "max_start_power", type = "U16"},      -- 51-52 (Max Start Power)
    {field = "padding_8", type = "U16"},            -- 53-54 (Padding)
    {field = "direction", type = "U8"},              -- 55 (Direction, F3C Autorotation)
    {field = "f3c_auto", type = "U8"},               -- 56 (F3C Autorotation)

    {field = "current_limit", type = "U16"},        -- 57-58
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
