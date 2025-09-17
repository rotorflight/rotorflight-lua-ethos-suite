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
local API_NAME = "RC_TUNING" -- API name (must be same as filename)
local MSP_API_CMD_READ = 111 -- Command identifier 
local MSP_API_CMD_WRITE = 204 -- Command identifier 
local MSP_REBUILD_ON_WRITE = true -- Rebuild the payload on write; keep true to ensure proper defaults after changing rates type

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rates_type",              type = "U8",  apiVersion = 12.06, simResponse = {4},  min = 0, max = 6,    default = 4,  tableIdxInc = -1, table = {"NONE", "BETAFLIGHT", "RACEFLIGHT", "KISS", "ACTUAL", "QUICK"}, help = "@i18n(api.RC_TUNING.rates_type)@"},
    {field = "rcRates_1",               type = "U8",  apiVersion = 12.06, simResponse = {18}, help = "@i18n(api.RC_TUNING.rcRates_1)@"},
    {field = "rcExpo_1",                type = "U8",  apiVersion = 12.06, simResponse = {25}, help = "@i18n(api.RC_TUNING.rcExpo_1)@"},
    {field = "rates_1",                 type = "U8",  apiVersion = 12.06, simResponse = {32}, help = "@i18n(api.RC_TUNING.rates_1)@"},
    {field = "response_time_1",         type = "U8",  apiVersion = 12.06, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_1)@"},
    {field = "accel_limit_1",           type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_1)@"},
    {field = "rcRates_2",               type = "U8",  apiVersion = 12.06, simResponse = {18}, help = "@i18n(api.RC_TUNING.rcRates_2)@"},
    {field = "rcExpo_2",                type = "U8",  apiVersion = 12.06, simResponse = {25}, help = "@i18n(api.RC_TUNING.rcExpo_2)@"},
    {field = "rates_2",                 type = "U8",  apiVersion = 12.06, simResponse = {32}, help = "@i18n(api.RC_TUNING.rates_2)@"},
    {field = "response_time_2",         type = "U8",  apiVersion = 12.06, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_2)@"},
    {field = "accel_limit_2",           type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_2)@"},
    {field = "rcRates_3",               type = "U8",  apiVersion = 12.06, simResponse = {32}, help = "@i18n(api.RC_TUNING.rcRates_3)@"},
    {field = "rcExpo_3",                type = "U8",  apiVersion = 12.06, simResponse = {50}, help = "@i18n(api.RC_TUNING.rcExpo_3)@"},
    {field = "rates_3",                 type = "U8",  apiVersion = 12.06, simResponse = {45}, help = "@i18n(api.RC_TUNING.rates_3)@"},
    {field = "response_time_3",         type = "U8",  apiVersion = 12.06, simResponse = {10}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_3)@"},
    {field = "accel_limit_3",           type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_3)@" },
    {field = "rcRates_4",               type = "U8",  apiVersion = 12.06, simResponse = {56}, help = "@i18n(api.RC_TUNING.rcRates_4)@"},
    {field = "rcExpo_4",                type = "U8",  apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.RC_TUNING.rcExpo_4)@"},
    {field = "rates_4",                 type = "U8",  apiVersion = 12.06, simResponse = {56}, help = "@i18n(api.RC_TUNING.rates_4)@"},
    {field = "response_time_4",         type = "U8",  apiVersion = 12.06, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_4)@"},
    {field = "accel_limit_4",           type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_4)@"},
    {field = "setpoint_boost_gain_1",   type = "U8",  apiVersion = 12.08, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_1)@"},
    {field = "setpoint_boost_cutoff_1", type = "U8",  apiVersion = 12.08, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_1)@"},
    {field = "setpoint_boost_gain_2",   type = "U8",  apiVersion = 12.08, simResponse = {0}, min = 0, max = 250,  default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_2)@"},
    {field = "setpoint_boost_cutoff_2", type = "U8",  apiVersion = 12.08, simResponse = {90}, min = 0, max = 250, unit = "Hz" , default = 90, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_2)@"},
    {field = "setpoint_boost_gain_3",   type = "U8",  apiVersion = 12.08, simResponse = {0}, min = 0, max = 250,  default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_3)@"},
    {field = "setpoint_boost_cutoff_3", type = "U8",  apiVersion = 12.08, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_3)@"},
    {field = "setpoint_boost_gain_4",   type = "U8",  apiVersion = 12.08, simResponse = {0}, min = 0, max = 250,  default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_4)@"},
    {field = "setpoint_boost_cutoff_4", type = "U8",  apiVersion = 12.08, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_4)@"},
    {field = "yaw_dynamic_ceiling_gain", type = "U8",  apiVersion = 12.08, simResponse = {30} , default = 30, min = 0, max = 250, help = "@i18n(api.RC_TUNING.yaw_dynamic_ceiling_gain)@"},
    {field = "yaw_dynamic_deadband_gain", type = "U8", apiVersion = 12.08, simResponse = {30}, default = 30, min = 0, max = 250, help = "@i18n(api.RC_TUNING.yaw_dynamic_deadband_gain)@"},
    {field = "yaw_dynamic_deadband_filter", type = "U8", apiVersion = 12.08, simResponse = {60}, scale = 10, decimals = 1, default = 60, min = 0, max = 250, unit="Hz", help = "@i18n(api.RC_TUNING.yaw_dynamic_deadband_filter)@"},

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
    setTimeout = setTimeout
}
