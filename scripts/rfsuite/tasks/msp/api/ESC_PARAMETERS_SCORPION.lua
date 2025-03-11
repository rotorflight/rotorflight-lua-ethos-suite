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
local API_NAME = "ESC_PARAMETERS_SCORPION" -- API name (must be same as filename)
local MSP_API_CMD_READ = 217 -- Command identifier 
local MSP_API_CMD_WRITE = 218 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 
local MSP_SIGNATURE = 0x53
local MSP_HEADER_BYTES = 2

-- Tables used in structure below
local escMode = {rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_heligov"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_helistore"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_vbar"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_extgov"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_airplane"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_boat"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_quad")}
local rotation = {rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_ccw"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_cw")}
local becVoltage = {"5.1 V", "6.1 V", "7.3 V", "8.3 V", "Disabled"}
local teleProtocol = {rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_standard"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_vbar"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_exbus"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_unsolicited"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_futsbus")}
local onOff = {rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_on"), rfsuite.i18n.get("api.ESC_PARAMETERS_SCORPION.tbl_off")}

local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",       type = "U8",  apiVersion = 12.07, simResponse = {83}},
    {field = "esc_command",         type = "U8",  apiVersion = 12.07, simResponse = {128}},
    {field = "escinfo_1",           type = "U8",  apiVersion = 12.07, simResponse = {84}},
    {field = "escinfo_2",           type = "U8",  apiVersion = 12.07, simResponse = {114}},
    {field = "escinfo_3",           type = "U8",  apiVersion = 12.07, simResponse = {105}},
    {field = "escinfo_4",           type = "U8",  apiVersion = 12.07, simResponse = {98}},
    {field = "escinfo_5",           type = "U8",  apiVersion = 12.07, simResponse = {117}},
    {field = "escinfo_6",           type = "U8",  apiVersion = 12.07, simResponse = {110}},
    {field = "escinfo_7",           type = "U8",  apiVersion = 12.07, simResponse = {117}},
    {field = "escinfo_8",           type = "U8",  apiVersion = 12.07, simResponse = {115}},
    {field = "escinfo_9",           type = "U8",  apiVersion = 12.07, simResponse = {32}},
    {field = "escinfo_10",          type = "U8",  apiVersion = 12.07, simResponse = {69}},
    {field = "escinfo_11",          type = "U8",  apiVersion = 12.07, simResponse = {83}},
    {field = "escinfo_12",          type = "U8",  apiVersion = 12.07, simResponse = {67}},
    {field = "escinfo_13",          type = "U8",  apiVersion = 12.07, simResponse = {45}},
    {field = "escinfo_14",          type = "U8",  apiVersion = 12.07, simResponse = {54}},
    {field = "escinfo_15",          type = "U8",  apiVersion = 12.07, simResponse = {83}},
    {field = "escinfo_16",          type = "U8",  apiVersion = 12.07, simResponse = {45}},
    {field = "escinfo_17",          type = "U8",  apiVersion = 12.07, simResponse = {56}},
    {field = "escinfo_18",          type = "U8",  apiVersion = 12.07, simResponse = {48}},
    {field = "escinfo_19",          type = "U8",  apiVersion = 12.07, simResponse = {65}},
    {field = "escinfo_20",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_21",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_22",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_23",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_24",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_25",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_26",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_27",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_28",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_29",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_30",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "escinfo_31",          type = "U8",  apiVersion = 12.07, simResponse = {4}},
    {field = "escinfo_32",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "esc_mode",            type = "U16", apiVersion = 12.07, simResponse = {3, 0}, min = 0, max = #escMode, tableIdxInc = -1, table = escMode},
    {field = "bec_voltage",         type = "U16", apiVersion = 12.07, simResponse = {3, 0}, min = 0, max = #becVoltage, tableIdxInc = -1, table = becVoltage},
    {field = "rotation",            type = "U16", apiVersion = 12.07, simResponse = {1, 0}, min = 0, max = #rotation, tableIdxInc = -1, table = rotation},
    {field = "telemetry_protocol",  type = "U16", apiVersion = 12.07, simResponse = {3, 0}, min = 0, max = #teleProtocol, tableIdxInc = -1},
    {field = "protection_delay",    type = "U16", apiVersion = 12.07, simResponse = {136, 19}, min = 0, max = 5000, unit = "s", scale = 1000},
    {field = "min_voltage",         type = "U16", apiVersion = 12.07, simResponse = {22, 3}, min = 0, max = 7000, unit = "v", decimals = 1, scale = 100},
    {field = "max_temperature",     type = "U16", apiVersion = 12.07, simResponse = {16, 39}, min = 0, max = 40000, unit = "°", scale = 100},
    {field = "max_current",         type = "U16", apiVersion = 12.07, simResponse = {64, 31}, min = 0, max = 30000, unit = "A", scale = 100},
    {field = "cutoff_handling",     type = "U16", apiVersion = 12.07, simResponse = {136, 19},min = 0, max = 10000, unit = "%", scale = 100},
    {field = "max_used",            type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 6000, unit = "Ah", scale = 100},
    {field = "motor_startup_sound", type = "U16", apiVersion = 12.07, simResponse = {1, 0}, min = 0, max = #onOff, tableIdxInc = -1, table = onOff},
    {field = "padding_1",           type = "U16", apiVersion = 12.07, simResponse = {7, 2}},
    {field = "padding_2",           type = "U16", apiVersion = 12.07, simResponse = {0, 6}},
    {field = "padding_3",           type = "U16", apiVersion = 12.07, simResponse = {63, 0}},
    {field = "soft_start_time",     type = "U16", apiVersion = 12.07, simResponse = {160, 15}, unit = "s", min = 0, max = 60000, scale = 1000},
    {field = "runup_time",          type = "U16", apiVersion = 12.07, simResponse = {64, 31},unit = "s", min = 0, max = 60000, scale = 1000},
    {field = "bailout",             type = "U16", apiVersion = 12.07, simResponse = {208, 7},unit = "s", min = 0, max = 100000, scale = 1000},
    {field = "gov_proportional",    type = "U32", apiVersion = 12.07, simResponse = {100, 0, 0, 0}, min = 30, max = 180, scale = 100},
    {field = "gov_integral",        type = "U32", apiVersion = 12.07, simResponse = {200, 0, 0, 0}, min = 150, max = 250, scale = 100},
}

-- Process structure in one pass
local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE =
    rfsuite.tasks.msp.api.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- set read structure
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

-- Variable to store parsed MSP data
local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.tasks.msp.api.createHandlers()

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
            local structure = MSP_API_STRUCTURE_READ
            rfsuite.tasks.msp.api.parseMSPData(buf, structure, nil, nil, function(result)
                mspData = result
                if #buf >= MSP_MIN_BYTES then
                    local completeHandler = handlers.getCompleteHandler()
                    if completeHandler then completeHandler(self, buf) end
                end
            end)
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT  
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = suppliedPayload or rfsuite.tasks.msp.api.buildWritePayload(API_NAME, payloadData,MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE),
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
    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    payloadData[fieldName] = value
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
