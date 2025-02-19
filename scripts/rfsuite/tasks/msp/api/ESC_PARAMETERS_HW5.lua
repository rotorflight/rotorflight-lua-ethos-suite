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
local API_NAME = "ESC_PARAMETERS_HW5" -- API name (must be same as filename)
local MSP_API_CMD_READ = 217 -- Command identifier 
local MSP_API_CMD_WRITE = 218 -- Command identifier 
local MSP_SIGNATURE = 0xFD
local MSP_HEADER_BYTES = 2

-- some tables used in structure below
local flightMode = {"Fixed Wing", "Heli Ext Governor", "Heli Governor", "Heli Governor Store"}
local rotation = {"CW", "CCW"}
local voltages = {"5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9", "7.0", "7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7", "7.8", "7.9", "8.0", "8.1", "8.2", "8.3", "8.4"}
local lipoCellCount = {"Auto Calculate", "3S", "4S", "5S", "6S", "7S", "8S", "9S", "10S", "11S", "12S", "13S", "14S"}
local cutoffType = {"Soft Cutoff", "Hard Cutoff"}
local cutoffVoltage = {"Disabled", "2.8", "2.9", "3.0", "3.1", "3.2", "3.3", "3.4", "3.5", "3.6", "3.7", "3.8"}
local restartTime = {"1s", "1.5s", "2s", "2.5s", "3s"}
local startupPower = {"1", "2", "3", "4", "5", "6", "7"}
local enabledDisabled = {"Enabled", "Disabled"}
local brakeType = {"Disabled", "Normal", "Proportional", "Reverse"}

local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",       type = "U8", apiVersion = 12.07, simResponse = {253}},
    {field = "esc_command",         type = "U8", apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_1",           type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_2",           type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_3",           type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_4",           type = "U8", apiVersion = 12.07, simResponse = {80}},
    {field = "escinfo_5",           type = "U8", apiVersion = 12.07, simResponse = {76}},
    {field = "escinfo_6",           type = "U8", apiVersion = 12.07, simResponse = {45}},
    {field = "escinfo_7",           type = "U8", apiVersion = 12.07, simResponse = {48}},
    {field = "escinfo_8",           type = "U8", apiVersion = 12.07, simResponse = {52}},
    {field = "escinfo_9",           type = "U8", apiVersion = 12.07, simResponse = {46}},
    {field = "escinfo_10",          type = "U8", apiVersion = 12.07, simResponse = {49}},
    {field = "escinfo_11",          type = "U8", apiVersion = 12.07, simResponse = {46}},
    {field = "escinfo_12",          type = "U8", apiVersion = 12.07, simResponse = {48}},
    {field = "escinfo_13",          type = "U8", apiVersion = 12.07, simResponse = {50}},
    {field = "escinfo_14",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_15",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_16",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_17",          type = "U8", apiVersion = 12.07, simResponse = {72}},
    {field = "escinfo_18",          type = "U8", apiVersion = 12.07, simResponse = {87}},
    {field = "escinfo_19",          type = "U8", apiVersion = 12.07, simResponse = {49}},
    {field = "escinfo_20",          type = "U8", apiVersion = 12.07, simResponse = {49}},
    {field = "escinfo_21",          type = "U8", apiVersion = 12.07, simResponse = {48}},
    {field = "escinfo_22",          type = "U8", apiVersion = 12.07, simResponse = {54}},
    {field = "escinfo_23",          type = "U8", apiVersion = 12.07, simResponse = {95}},
    {field = "escinfo_24",          type = "U8", apiVersion = 12.07, simResponse = {86}},
    {field = "escinfo_25",          type = "U8", apiVersion = 12.07, simResponse = {49}},
    {field = "escinfo_26",          type = "U8", apiVersion = 12.07, simResponse = {48}},
    {field = "escinfo_27",          type = "U8", apiVersion = 12.07, simResponse = {48}},
    {field = "escinfo_28",          type = "U8", apiVersion = 12.07, simResponse = {52}},
    {field = "escinfo_29",          type = "U8", apiVersion = 12.07, simResponse = {53}},
    {field = "escinfo_30",          type = "U8", apiVersion = 12.07, simResponse = {54}},
    {field = "escinfo_31",          type = "U8", apiVersion = 12.07, simResponse = {78}},
    {field = "escinfo_32",          type = "U8", apiVersion = 12.07, simResponse = {66}},
    {field = "escinfo_33",          type = "U8", apiVersion = 12.07, simResponse = {80}},
    {field = "escinfo_34",          type = "U8", apiVersion = 12.07, simResponse = {108}},
    {field = "escinfo_35",          type = "U8", apiVersion = 12.07, simResponse = {97}},
    {field = "escinfo_36",          type = "U8", apiVersion = 12.07, simResponse = {116}},
    {field = "escinfo_37",          type = "U8", apiVersion = 12.07, simResponse = {105}},
    {field = "escinfo_38",          type = "U8", apiVersion = 12.07, simResponse = {110}},
    {field = "escinfo_39",          type = "U8", apiVersion = 12.07, simResponse = {117}},
    {field = "escinfo_40",          type = "U8", apiVersion = 12.07, simResponse = {109}},
    {field = "escinfo_41",          type = "U8", apiVersion = 12.07, simResponse = {95}},
    {field = "escinfo_42",          type = "U8", apiVersion = 12.07, simResponse = {86}},
    {field = "escinfo_43",          type = "U8", apiVersion = 12.07, simResponse = {53}},
    {field = "escinfo_44",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_45",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_46",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_47",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_48",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_49",          type = "U8", apiVersion = 12.07, simResponse = {80}},
    {field = "escinfo_50",          type = "U8", apiVersion = 12.07, simResponse = {108}},
    {field = "escinfo_51",          type = "U8", apiVersion = 12.07, simResponse = {97}},
    {field = "escinfo_52",          type = "U8", apiVersion = 12.07, simResponse = {116}},
    {field = "escinfo_53",          type = "U8", apiVersion = 12.07, simResponse = {105}},
    {field = "escinfo_54",          type = "U8", apiVersion = 12.07, simResponse = {110}},
    {field = "escinfo_55",          type = "U8", apiVersion = 12.07, simResponse = {117}},
    {field = "escinfo_56",          type = "U8", apiVersion = 12.07, simResponse = {109}},
    {field = "escinfo_57",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_58",          type = "U8", apiVersion = 12.07, simResponse = {86}},
    {field = "escinfo_59",          type = "U8", apiVersion = 12.07, simResponse = {53}},
    {field = "escinfo_60",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_61",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_62",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_63",          type = "U8", apiVersion = 12.07, simResponse = {32}},
    {field = "flight_mode",         type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #flightMode, tableIdxInc = -1, table = flightMode},
    {field = "lipo_cell_count",     type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #lipoCellCount, tableIdxInc = -1, table = lipoCellCount},
    {field = "volt_cutoff_type",    type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #cutoffType, tableIdxInc = -1, table = cutoffType},
    {field = "cutoff_voltage",      type = "U8", apiVersion = 12.07, simResponse = {3}, default = 3, min = 0, max = #cutoffVoltage, tableIdxInc = -1, table = cutoffVoltage},
    {field = "bec_voltage",         type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #voltages, tableIdxInc = -1, table = voltages},
    {field = "startup_time",        type = "U8", apiVersion = 12.07, simResponse = {11}},
    {field = "gov_p_gain",          type = "U8", apiVersion = 12.07, simResponse = {6}},
    {field = "gov_i_gain",          type = "U8", apiVersion = 12.07, simResponse = {5}},
    {field = "auto_restart",        type = "U8", apiVersion = 12.07, simResponse = {25}, default = 25, units = "s", min = 0, max = 90},
    {field = "restart_time",        type = "U8", apiVersion = 12.07, simResponse = {1} , default = 1, tableIdxInc = -1, min = 0, max = #restartTime, table = restartTime},
    {field = "brake_type",          type = "U8", apiVersion = 12.07, simResponse = {0} , default = 0, min = 0, max = #brakeType, xvals = {76}, table = brakeType, tableIdxInc = -1},
    {field = "brake_force",         type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = 100},
    {field = "timing",              type = "U8", apiVersion = 12.07, simResponse = {24}},
    {field = "rotation",            type = "U8", apiVersion = 12.07, simResponse = {0}, default = 0, min = 0, max = #rotation, tableIdxInc = -1, table = rotation},
    {field = "active_freewheel",    type = "U8", apiVersion = 12.07, simResponse = {0}, min = 0, max = #enabledDisabled, table = enabledDisabled, tableIdxInc = -1},
    {field = "startup_power",       type = "U8", apiVersion = 12.07, simResponse = {2}, default = 2, min = 0, max = #startupPower, tableIdxInc = -1, table = startupPower}
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
    setTimeout = setTimeout,
    mspSignature = MSP_SIGNATURE,
    mspHeaderBytes = MSP_HEADER_BYTES,
    simulatorResponse = MSP_API_SIMULATOR_RESPONSE
}
