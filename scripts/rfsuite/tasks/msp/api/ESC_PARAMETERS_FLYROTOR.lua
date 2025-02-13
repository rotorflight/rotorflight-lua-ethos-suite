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
local MSP_SIGNATURE = 0x73
local MSP_HEADER_BYTES = 2

local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",           type = "U8",  apiVersion = 12.07, simResponse = {115}},
    {field = "esc_command",             type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_1",               type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_2",               type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_3",               type = "U8",  apiVersion = 12.07, simResponse = {150}},
    {field = "escinfo_4",               type = "U8",  apiVersion = 12.07, simResponse = {231}},
    {field = "escinfo_5",               type = "U8",  apiVersion = 12.07, simResponse = {79}},
    {field = "escinfo_6",               type = "U8",  apiVersion = 12.07, simResponse = {190}},
    {field = "escinfo_7",               type = "U8",  apiVersion = 12.07, simResponse = {216}},
    {field = "escinfo_8",               type = "U8",  apiVersion = 12.07, simResponse = {78}},
    {field = "escinfo_9",               type = "U8",  apiVersion = 12.07, simResponse = {29}},
    {field = "escinfo_10",              type = "U8",  apiVersion = 12.07, simResponse = {169}},
    {field = "escinfo_11",              type = "U8",  apiVersion = 12.07, simResponse = {244}},
    {field = "escinfo_12",              type = "U8",  apiVersion = 12.07, simResponse = {1}},
    {field = "escinfo_13",              type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_14",              type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_15",              type = "U8",  apiVersion = 12.07, simResponse = {1}},
    {field = "escinfo_16",              type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_17",              type = "U8",  apiVersion = 12.07, simResponse = {8}},
    {field = "escinfo_18",              type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "throttle_min",            type = "U16", apiVersion = 12.07, simResponse = {4, 76},       byteorder = "big", help="Minimum throttle value"},
    {field = "throttle_max",            type = "U16", apiVersion = 12.07, simResponse = {7, 148},      byteorder = "big", help="Maximum throttle value"},
    {field = "governor",                type = "U8",  apiVersion = 12.07, simResponse = {0}, table = {"External Governor", "ESC Governor"}, tableIdxInc = -1},
    {field = "cell_count",              type = "U8",  apiVersion = 12.07, simResponse = {6}, min = 4, max = 14, default = 6, help="Number of cells in the battery"},
    {field = "low_voltage_protection",  type = "U8",  apiVersion = 12.07, simResponse = {30},min = 28, max = 38, scale = 10, default = 30, decimals = 1, unit = "V", help="Voltage at which we cut poer to the motor"},
    {field = "temperature_protection",  type = "U8",  apiVersion = 12.07, simResponse = {125},min = 50, max = 135, default = 125, unit = "°", help="Temperature at which we cut power to the motor"},
    {field = "bec_voltage",             type = "U8",  apiVersion = 12.07, simResponse = {0}, unit = "V", table={"7.5", "8.0", "8.5", "12"}, tableIdxInc = -1},
    {field = "timing_angle",            type = "U8",  apiVersion = 12.07, simResponse = {10},min = 1, max = 10, default = 5, unit = "°", help="Timing angle for the motor"},
    {field = "motor_direction",         type = "U8",  apiVersion = 12.07, simResponse = {0}, table={"CW", "CCW"}, tableIdxInc = -1},
    {field = "starting_torque",         type = "U8",  apiVersion = 12.07, simResponse = {3},min = 1, max = 15, default = 3, help="Starting torque for the motor"},
    {field = "response_speed",          type = "U8",  apiVersion = 12.07, simResponse = {5},min = 1, max = 15, default = 5, help="Response speed for the motor"},
    {field = "buzzer_volume",           type = "U8",  apiVersion = 12.07, simResponse = {1},min = 1, max = 5, default = 2, help="Buzzer volume"},
    {field = "current_gain",            type = "S8",  apiVersion = 12.07, simResponse = {20},min = 0, max = 40, default = 20, offset = -20, help="Gain value for the current sensor"},
    {field = "fan_control",             type = "U8",  apiVersion = 12.07, simResponse = {0}, table = {"Automatic", "Always On"}, tableIdxInc = -1},
    {field = "soft_start",              type = "U8",  apiVersion = 12.07, simResponse = {15}, min = 5, max = 55, help="Soft start value"},
    {field = "gov_p",                   type = "U16", apiVersion = 12.07, simResponse = {0, 45}, min = 1, max = 100, default = 45, byteorder = "big", help="Proportional value for the governor"},
    {field = "gov_i",                   type = "U16", apiVersion = 12.07, simResponse = {0, 35}, min = 1, max = 100, default = 35, byteorder = "big", help="Integral value for the governor"},
    {field = "gov_d",                   type = "U16", apiVersion = 12.07, simResponse = {0, 0},  min = 0, max = 100, default = 0,  byteorder = "big", help="Derivative value for the governor"},
    {field = "motor_erpm_max",          type = "U24", apiVersion = 12.07, simResponse = {1, 134, 160}, min = 0, max = 1000000, step = 100, byteorder = "big", help="Maximum RPM"}
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
