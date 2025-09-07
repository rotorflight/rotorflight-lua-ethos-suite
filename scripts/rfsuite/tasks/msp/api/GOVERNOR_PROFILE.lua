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
local API_NAME = "GOVERNOR_PROFILE" -- API name (must be same as filename)
local MSP_API_CMD_READ = 148 -- Command identifier 
local MSP_API_CMD_WRITE = 149 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 

local MSP_API_STRUCTURE_READ_DATA

if rfsuite.utils.apiVersionCompare(">=", "12.09") then

    local offOn = {rfsuite.i18n.get("api.GOVERNOR_PROFILE.tbl_off"), rfsuite.i18n.get("api.GOVERNOR_PROFILE.tbl_on")}

    local governor_flags_bitmap = {
        { field = "fc_throttle_curve",    table = offOn, tableIdxInc = -1},    -- bit 0
        { field = "tx_precomp_curve",     table = offOn, tableIdxInc = -1 },    -- bit 1
        { field = "fallback_precomp",     table = offOn, tableIdxInc = -1 },    -- bit 2
        { field = "voltage_comp",         table = offOn, tableIdxInc = -1 },    -- bit 3
        { field = "pid_spoolup",          table = offOn, tableIdxInc = -1 },    -- bit 4
        { field = "hs_adjustment",        table = offOn, tableIdxInc = -1 },    -- bit 5
        { field = "dyn_min_throttle",     table = offOn, tableIdxInc = -1 },    -- bit 6
        { field = "autorotation",         table = offOn, tableIdxInc = -1 },    -- bit 7
        { field = "suspend",              table = offOn, tableIdxInc = -1 },    -- bit 8
        { field = "bypass",               table = offOn, tableIdxInc = -1 },    -- bit 9 (up to 15 bits can be defined)
    }

    MSP_API_STRUCTURE_READ_DATA = {
        {field = "governor_headspeed",            type = "U16", apiVersion = 12.09, simResponse = {208, 7}, min = 0,   max = 50000, default = 1000, unit = "rpm", step = 10},
        {field = "governor_gain",                 type = "U8",  apiVersion = 12.09, simResponse = {100},    min = 0,   max = 250,   default = 40},
        {field = "governor_p_gain",               type = "U8",  apiVersion = 12.09, simResponse = {10},     min = 0,   max = 250,   default = 40},
        {field = "governor_i_gain",               type = "U8",  apiVersion = 12.09, simResponse = {125},    min = 0,   max = 250,   default = 50},
        {field = "governor_d_gain",               type = "U8",  apiVersion = 12.09, simResponse = {5},      min = 0,   max = 250,   default = 0},
        {field = "governor_f_gain",               type = "U8",  apiVersion = 12.09, simResponse = {20},     min = 0,   max = 250,   default = 10},
        {field = "governor_tta_gain",             type = "U8",  apiVersion = 12.09, simResponse = {0},      min = 0,   max = 250,   default = 0},
        {field = "governor_tta_limit",            type = "U8",  apiVersion = 12.09, simResponse = {20},     min = 0,   max = 250,   default = 20,   unit = "%"},
        {field = "governor_yaw_weight",           type = "U8",  apiVersion = 12.09, simResponse = {10},     min = 0,   max = 250,   default = 0},
        {field = "governor_cyclic_weight",        type = "U8",  apiVersion = 12.09, simResponse = {40},     min = 0,   max = 250,   default = 10},
        {field = "governor_collective_weight",    type = "U8",  apiVersion = 12.09, simResponse = {100},    min = 0,   max = 250,   default = 100},
        {field = "governor_max_throttle",         type = "U8",  apiVersion = 12.09, simResponse = {100},    min = 40,  max = 100,   default = 100,  unit = "%"},
        {field = "governor_min_throttle",         type = "U8",  apiVersion = 12.09, simResponse = {10},     min = 0,   max = 100,   default = 10,   unit = "%"},
        {field = "governor_fallback_drop",        type = "U8",  apiVersion = 12.09, simResponse = {10},     min = 0,   max = 50,   default = 10,  unit = "%"},
        {field = "governor_flags",                type = "U16", apiVersion = 12.09, simResponse = {251, 3}, bitmap = governor_flags_bitmap},
    }
else
    MSP_API_STRUCTURE_READ_DATA = {
        {field = "governor_headspeed",            type = "U16", apiVersion = 12.06, simResponse = {208, 7}, min = 0,   max = 50000, default = 1000, unit = "rpm", step = 10},
        {field = "governor_gain",                 type = "U8",  apiVersion = 12.06, simResponse = {100},    min = 0,   max = 250,   default = 40},
        {field = "governor_p_gain",               type = "U8",  apiVersion = 12.06, simResponse = {10},     min = 0,   max = 250,   default = 40},
        {field = "governor_i_gain",               type = "U8",  apiVersion = 12.06, simResponse = {125},    min = 0,   max = 250,   default = 50},
        {field = "governor_d_gain",               type = "U8",  apiVersion = 12.06, simResponse = {5},      min = 0,   max = 250,   default = 0},
        {field = "governor_f_gain",               type = "U8",  apiVersion = 12.06, simResponse = {20},     min = 0,   max = 250,   default = 10},
        {field = "governor_tta_gain",             type = "U8",  apiVersion = 12.06, simResponse = {0},      min = 0,   max = 250,   default = 0},
        {field = "governor_tta_limit",            type = "U8",  apiVersion = 12.06, simResponse = {20},     min = 0,   max = 250,   default = 20,   unit = "%"},
        {field = "governor_yaw_ff_weight",        type = "U8",  apiVersion = 12.06, simResponse = {10},     min = 0,   max = 250,   default = 0},
        {field = "governor_cyclic_ff_weight",     type = "U8",  apiVersion = 12.06, simResponse = {40},     min = 0,   max = 250,   default = 10},
        {field = "governor_collective_ff_weight", type = "U8",  apiVersion = 12.06, simResponse = {100},    min = 0,   max = 250,   default = 100},
        {field = "governor_max_throttle",         type = "U8",  apiVersion = 12.06, simResponse = {100},    min = 40,  max = 100,   default = 100,  unit = "%"},
        {field = "governor_min_throttle",         type = "U8",  apiVersion = 12.06, simResponse = {10},     min = 0,   max = 100,   default = 10,   unit = "%"}
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
