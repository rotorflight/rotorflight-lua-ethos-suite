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
local MSP_API_SIMULATOR_RESPONSE = {253, 0, 32, 32, 32, 80, 76, 45, 48, 52, 46, 49, 46, 48, 50, 32, 32, 32, 72, 87, 49, 49, 48, 54, 95, 86, 49, 48, 48, 52, 53, 54, 78, 66, 80, 108, 97, 116, 105, 110, 117, 109, 95, 86, 53, 32, 32, 32, 32, 32, 80, 108, 97, 116, 105, 110, 117, 109, 32, 86, 53, 32, 32, 32, 32, 0, 0, 0, 3, 0, 11, 6, 5, 25, 1, 0, 0, 24, 0, 0, 2} -- Default simulator response
local MSP_SIGNATURE = 0xFD
local MSP_HEADER_BYTES = 2

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ = {
    {field = "esc_signature",       type = "U8"}, -- 1
    {field = "esc_command",         type = "U8"}, -- 2

    -- payload containing info to decode the esc info from
    {field = "escinfo_1",           type = "U8"}, -- 3
    {field = "escinfo_2",           type = "U8"}, -- 4
    {field = "escinfo_3",           type = "U8"}, -- 5
    {field = "escinfo_4",           type = "U8"}, -- 6
    {field = "escinfo_5",           type = "U8"}, -- 7
    {field = "escinfo_6",           type = "U8"}, -- 8
    {field = "escinfo_7",           type = "U8"}, -- 9
    {field = "escinfo_8",           type = "U8"}, -- 10
    {field = "escinfo_9",           type = "U8"}, -- 11
    {field = "escinfo_10",          type = "U8"}, -- 12
    {field = "escinfo_11",          type = "U8"}, -- 13
    {field = "escinfo_12",          type = "U8"}, -- 14
    {field = "escinfo_13",          type = "U8"}, -- 15
    {field = "escinfo_14",          type = "U8"}, -- 16
    {field = "escinfo_15",          type = "U8"}, -- 17
    {field = "escinfo_16",          type = "U8"}, -- 18
    {field = "escinfo_17",          type = "U8"}, -- 19
    {field = "escinfo_18",          type = "U8"}, -- 20
    {field = "escinfo_19",          type = "U8"}, -- 21
    {field = "escinfo_20",          type = "U8"}, -- 22
    {field = "escinfo_21",          type = "U8"}, -- 23
    {field = "escinfo_22",          type = "U8"}, -- 24
    {field = "escinfo_23",          type = "U8"}, -- 25
    {field = "escinfo_24",          type = "U8"}, -- 26
    {field = "escinfo_25",          type = "U8"}, -- 27
    {field = "escinfo_26",          type = "U8"}, -- 28
    {field = "escinfo_27",          type = "U8"}, -- 29
    {field = "escinfo_28",          type = "U8"}, -- 30
    {field = "escinfo_29",          type = "U8"}, -- 31
    {field = "escinfo_30",          type = "U8"}, -- 32
    {field = "escinfo_31",          type = "U8"}, -- 33
    {field = "escinfo_32",          type = "U8"}, -- 34
    {field = "escinfo_33",          type = "U8"}, -- 35
    {field = "escinfo_34",          type = "U8"}, -- 36
    {field = "escinfo_35",          type = "U8"}, -- 37
    {field = "escinfo_36",          type = "U8"}, -- 38
    {field = "escinfo_37",          type = "U8"}, -- 39
    {field = "escinfo_38",          type = "U8"}, -- 40
    {field = "escinfo_39",          type = "U8"}, -- 41
    {field = "escinfo_40",          type = "U8"}, -- 42
    {field = "escinfo_41",          type = "U8"}, -- 43
    {field = "escinfo_42",          type = "U8"}, -- 44
    {field = "escinfo_43",          type = "U8"}, -- 45
    {field = "escinfo_44",          type = "U8"}, -- 46
    {field = "escinfo_45",          type = "U8"}, -- 47
    {field = "escinfo_46",          type = "U8"}, -- 48
    {field = "escinfo_47",          type = "U8"}, -- 49
    {field = "escinfo_48",          type = "U8"}, -- 50
    {field = "escinfo_49",          type = "U8"}, -- 51
    {field = "escinfo_50",          type = "U8"}, -- 52
    {field = "escinfo_51",          type = "U8"}, -- 53
    {field = "escinfo_52",          type = "U8"}, -- 54
    {field = "escinfo_53",          type = "U8"}, -- 55
    {field = "escinfo_54",          type = "U8"}, -- 56
    {field = "escinfo_55",          type = "U8"}, -- 57
    {field = "escinfo_56",          type = "U8"}, -- 58
    {field = "escinfo_57",          type = "U8"}, -- 59
    {field = "escinfo_58",          type = "U8"}, -- 60
    {field = "escinfo_59",          type = "U8"}, -- 61
    {field = "escinfo_60",          type = "U8"}, -- 62
    {field = "escinfo_61",          type = "U8"}, -- 63
    {field = "escinfo_62",          type = "U8"}, -- 64
    {field = "escinfo_63",          type = "U8"}, -- 65

    {field = "flight_mode",         type = "U8"}, -- 66
    {field = "lipo_cell_count",     type = "U8"}, -- 67
    {field = "volt_cutoff_type",    type = "U8"}, -- 68
    {field = "cutoff_voltage",      type = "U8"}, -- 69
    {field = "bec_voltage",         type = "U8"}, -- 70
    {field = "startup_time",        type = "U8"}, -- 71
    {field = "gov_p_gain",          type = "U8"}, -- 72
    {field = "gov_i_gain",          type = "U8"}, -- 73
    {field = "auto_restart",        type = "U8"}, -- 74
    {field = "restart_time",        type = "U8"}, -- 75
    {field = "brake_type",          type = "U8"}, -- 76
    {field = "brake_force",         type = "U8"}, -- 77
    {field = "timing",              type = "U8"}, -- 78
    {field = "rotation",            type = "U8"}, -- 79
    {field = "active_freewheel",    type = "U8"}, -- 80
    {field = "startup_power",       type = "U8"}, -- 81
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
