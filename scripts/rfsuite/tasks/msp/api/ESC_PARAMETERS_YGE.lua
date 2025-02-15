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
local MSP_SIGNATURE = 0xA5
local MSP_HEADER_BYTES = 2

-- tables used in structure below
local escMode = {"Free (Attention!)", "Heli Ext Governor", "Heli Governor", "Heli Governor Store", "Aero Glider", "Aero Motor", "Aero F3A"}
local direction = {"Normal", "Reverse"}
local cuttoff = {"Off", "Slow Down", "Cutoff"}
local cuttoffVoltage = {"2.9 V", "3.0 V", "3.1 V", "3.2 V", "3.3 V", "3.4 V"}
local offOn = {"Off", "On"}
local startupResponse = {"Normal", "Smooth"}
local throttleResponse = {"Slow", "Medium", "Fast", "Custom (PC defined)"}
local motorTiming = {"Auto Normal", "Auto Efficient", "Auto Power", "Auto Extreme", "0 deg", "6 deg", "12 deg", "18 deg", "24 deg", "30 deg"}
local motorTimingToUI = {0, 4, 5, 6, 7, 8, 9, [16] = 0, [17] = 1, [18] = 2, [19] = 3}
local motorTimingFromUI = {0, 17, 18, 19, 1, 2, 3, 4, 5, 6}
local freewheel = {"Off", "Auto", "*unused*", "Always On"}

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",      type = "U8",  apiVersion = 12.07, simResponse = {165}},
    {field = "esc_command",        type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "esc_model",          type = "U8",  apiVersion = 12.07, simResponse = {32}},
    {field = "esc_version",        type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "governor",           type = "U16", apiVersion = 12.07, simResponse = {3, 0},  min = 1, max = #escMode, table = escMode, tableIdxInc = -1},
    {field = "lv_bec_voltage",     type = "U16", apiVersion = 12.07, simResponse = {55, 0}, unit = "v", min = 55, max = 84, scale = 10, decimals = 1},
    {field = "timing",             type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = #motorTiming, tableIdxInc = -1, table = motorTiming},
    {field = "acceleration",       type = "U16", apiVersion = 12.07, simResponse = {0, 0}},
    {field = "gov_p",              type = "U16", apiVersion = 12.07, simResponse = {4, 0},min = 1, max = 10},
    {field = "gov_i",              type = "U16", apiVersion = 12.07, simResponse = {3, 0},min = 1, max = 10},
    {field = "throttle_response",  type = "U16", apiVersion = 12.07, simResponse = {1, 0}, min = 0, max = #throttleResponse, tableIdxInc = -1, table = throttleResponse},
    {field = "auto_restart_time",  type = "U16", apiVersion = 12.07, simResponse = {1, 0},  min = 0, max = #cuttoff, tableIdxInc = -1, table = cuttoff},
    {field = "cell_cutoff",        type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 0, max = #cuttoffVoltage, tableIdxInc = -1, table = cuttoffVoltage},
    {field = "active_freewheel",   type = "U16", apiVersion = 12.07, simResponse = {3, 0},min = 0, max = #freewheel, tableIdxInc = -1, table = freewheel},
    {field = "padding_1",          type = "U16", apiVersion = 12.07, simResponse = {80, 3}},
    {field = "padding_2",          type = "U16", apiVersion = 12.07, simResponse = {131, 148}},
    {field = "padding_3",          type = "U16", apiVersion = 12.07, simResponse = {1, 0}},
    {field = "padding_4",          type = "U16", apiVersion = 12.07, simResponse = {30, 170}},
    {field = "padding_5",          type = "U16", apiVersion = 12.07, simResponse = {0, 0}},
    {field = "padding_6",          type = "U16", apiVersion = 12.07, simResponse = {3, 0}},
    {field = "stick_zero_us",      type = "U16", apiVersion = 12.07, simResponse = {86, 4} ,min = 900, max = 1900, unit = "us"},
    {field = "stick_range_us",     type = "U16", apiVersion = 12.07, simResponse = {22, 3}, min = 600, max = 1500, unit = "us"},
    {field = "padding_7",          type = "U16", apiVersion = 12.07, simResponse = {163, 15}},
    {field = "motor_poll_pairs",   type = "U16", apiVersion = 12.07, simResponse = {1, 0}, min = 1, max = 100},
    {field = "pinion_teeth",       type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 1, max = 255},
    {field = "main_teeth",         type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 1, max = 1800},
    {field = "min_start_power",    type = "U16", apiVersion = 12.07, simResponse = {20, 0}, min = 0, max = 26, unit = "%"},
    {field = "max_start_power",    type = "U16", apiVersion = 12.07, simResponse = {20, 0}, min = 0, max = 31, unit = "%"},
    {field = "padding_8",          type = "U16", apiVersion = 12.07, simResponse = {0, 0}},
    {field = "direction",          type = "U8",  apiVersion = 12.07, simResponse = {0}, min = 0, max = 1, tableIdxInc = -1, table = direction},
    {field = "f3c_auto",           type = "U8",  apiVersion = 12.07, simResponse = {0}, min = 0, max = 1, tableIdxInc = -1, table = offOn},
    {field = "current_limit",      type = "U16", apiVersion = 12.07, simResponse = {2, 19},  unit="A", min = 1, max = 65500, decimals = 2, scale = 100},
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
    setTimeout = setTimeout,
    mspSignature = MSP_SIGNATURE,
    mspHeaderBytes = MSP_HEADER_BYTES,
    simulatorResponse = MSP_API_SIMULATOR_RESPONSE
}
