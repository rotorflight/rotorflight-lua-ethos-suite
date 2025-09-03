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
local API_NAME = "GOVERNOR_CONFIG" -- API name (must be same as filename)
local MSP_API_CMD_READ = 142 -- Command identifier for MSP Mixer Config Read
local MSP_API_CMD_WRITE = 143 -- Command identifier for saving Mixer Config Settings
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 

-- define msp structure for reading and writing

local MSP_API_STRUCTURE_READ_DATA

if rfsuite.utils.apiVersionCompare(">=", "12.09") then

    local gov_modeTable ={[0] = rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_off"), rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_external"), rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_electric"), rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_nitro")}
    local throttleTypeTable ={[0] = rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_throttle_type_normal"), rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_throttle_type_off_on"),rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_throttle_type_off_idle_on"),rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_throttle_type_idle_auto_on")}

    MSP_API_STRUCTURE_READ_DATA = {
        {field = "gov_mode",                        type = "U8",  apiVersion = 12.09, simResponse = {2},    min = 0,  max = #gov_modeTable, table = gov_modeTable},
        {field = "gov_startup_time",                type = "U16", apiVersion = 12.09, simResponse = {200, 0}, min = 0,  max = 600, unit = "s", default = 200, decimals = 1, scale = 10},
        {field = "gov_spoolup_time",                type = "U16", apiVersion = 12.09, simResponse = {100, 0}, min = 0,  max = 600, unit = "s", default = 100, decimals = 1, scale = 10},
        {field = "gov_tracking_time",               type = "U16", apiVersion = 12.09, simResponse = {20, 0},  min = 0,  max = 100, unit = "s", default = 10,  decimals = 1, scale = 10},
        {field = "gov_recovery_time",               type = "U16", apiVersion = 12.09, simResponse = {20, 0},  min = 0,  max = 100, unit = "s", default = 21,  decimals = 1, scale = 10},
        {field = "gov_throttle_hold_timeout",       type = "U16", apiVersion = 12.09, simResponse = {50, 0},  min = 0,  max = 250, unit = "s", default = 5,  decimals = 1, scale = 10},
        {field = "gov_lost_headspeed_timeout",      type = "U16", apiVersion = 12.09, simResponse = {0, 0}},   -- padding in 12.09
        {field = "gov_autorotation_timeout",        type = "U16", apiVersion = 12.09, simResponse = {0, 0}},   -- padding in 12.09
        {field = "gov_autorotation_bailout_time",   type = "U16", apiVersion = 12.09, simResponse = {0, 0}},   -- padding in 12.09
        {field = "gov_autorotation_min_entry_time", type = "U16", apiVersion = 12.09, simResponse = {0, 0}},   -- padding in 12.09
        {field = "gov_handover_throttle",           type = "U8",  apiVersion = 12.09, simResponse = {20},   min = 0, max = 50,  unit = "%", default = 20},
        {field = "gov_pwr_filter",                  type = "U8",  apiVersion = 12.09, simResponse = {20}, unit = "Hz", min = 0, max = 250, default = 20},
        {field = "gov_rpm_filter",                  type = "U8",  apiVersion = 12.09, simResponse = {20}, unit = "Hz", min = 0, max = 250, default = 20},
        {field = "gov_tta_filter",                  type = "U8",  apiVersion = 12.09, simResponse = {0}, unit = "Hz", min = 0, max = 250, default = 20},
        {field = "gov_ff_filter",                   type = "U8",  apiVersion = 12.09, simResponse = {10}, unit = "Hz", min = 0, max = 25, default = 10},
        {field = "gov_spoolup_min_throttle",        type = "U8",  apiVersion = 12.09, simResponse = {0}} ,      -- padding in 12.09
        {field = "gov_d_filter",                    type = "U8",  apiVersion = 12.09, simResponse = {50}, unit = "Hz", min = 0, max = 250, default = 50, decimals = 1, scale = 10},
        {field = "gov_spooldown_time",              type = "U16", apiVersion = 12.09, simResponse = {30, 0}, min = 0,  max = 600, unit = "s", default = 100, decimals = 1, scale = 10},
        {field = "gov_throttle_type",               type = "U8",  apiVersion = 12.09, simResponse = {0}, min = 0, max = #throttleTypeTable, table = throttleTypeTable},
        {field = "gov_idle_collective",             type = "S8",  apiVersion = 12.09, simResponse = {161}, unit = "%", min = -100, max = 100, default = -95},
        {field = "gov_wot_collective",              type = "S8",  apiVersion = 12.09, simResponse = {246}, unit = "%", min = -100, max = 100, default = -10},
        {field = "governor_idle_throttle",          type = "U8",    apiVersion = 12.09, simResponse = {10},     min = 0,   max = 100,   default = 0,  unit = "%"},
        {field = "governor_auto_throttle",          type = "U8",    apiVersion = 12.09, simResponse = {10},     min = 0,   max = 100,   default = 0,  unit = "%"},

    }

else

    local gov_modeTable ={[0] = rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_off"), rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_passthrough"), rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_standard"), rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_mode1"), rfsuite.i18n.get("api.GOVERNOR_CONFIG.tbl_govmode_mode2")}

    MSP_API_STRUCTURE_READ_DATA = {
        {field = "gov_mode",                        type = "U8",  apiVersion = 12.06, simResponse = {3},    min = 0,  max = #gov_modeTable,   table = gov_modeTable},
        {field = "gov_startup_time",                type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0,  max = 600, unit = "s", default = 200, decimals = 1, scale = 10},
        {field = "gov_spoolup_time",                type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0,  max = 600, unit = "s", default = 100, decimals = 1, scale = 10},
        {field = "gov_tracking_time",               type = "U16", apiVersion = 12.06, simResponse = {20, 0},  min = 0,  max = 100, unit = "s", default = 10,  decimals = 1, scale = 10},
        {field = "gov_recovery_time",               type = "U16", apiVersion = 12.06, simResponse = {20, 0},  min = 0,  max = 100, unit = "s", default = 21,  decimals = 1, scale = 10},
        {field = "gov_zero_throttle_timeout",       type = "U16", apiVersion = 12.06, simResponse = {30, 0}},
        {field = "gov_lost_headspeed_timeout",      type = "U16", apiVersion = 12.06, simResponse = {10, 0}},
        {field = "gov_autorotation_timeout",        type = "U16", apiVersion = 12.06, simResponse = {0, 0}},
        {field = "gov_autorotation_bailout_time",   type = "U16", apiVersion = 12.06, simResponse = {0, 0}},
        {field = "gov_autorotation_min_entry_time", type = "U16", apiVersion = 12.06, simResponse = {50, 0}},
        {field = "gov_handover_throttle",           type = "U8",  apiVersion = 12.06, simResponse = {10},   min = 10, max = 50,  unit = "%", default = 20},
        {field = "gov_pwr_filter",                  type = "U8",  apiVersion = 12.06, simResponse = {5}},
        {field = "gov_rpm_filter",                  type = "U8",  apiVersion = 12.06, simResponse = {10}},
        {field = "gov_tta_filter",                  type = "U8",  apiVersion = 12.06, simResponse = {0}},
        {field = "gov_ff_filter",                   type = "U8",  apiVersion = 12.06, simResponse = {10}},
        {field = "gov_spoolup_min_throttle",        type = "U8",  apiVersion = 12.08, simResponse = {5},    min = 0,  max = 50,  unit = "%", default = 0},
    }    
end

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
