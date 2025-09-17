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
local API_NAME = "RESCUE_PROFILE" -- API name (must be same as filename)
local MSP_API_CMD_READ = 146 -- Command identifier 
local MSP_API_CMD_WRITE = 147 -- Command identifier
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write  

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rescue_mode",               type = "U8",  apiVersion = 12.06, simResponse = {1},   min = 0, max = 1,   default = 0,   table = {[0] = "@i18n(api.RESCUE_PROFILE.tbl_off)@", "@i18n(api.RESCUE_PROFILE.tbl_on)@"}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_mode)@"},
    {field = "rescue_flip_mode",          type = "U8",  apiVersion = 12.06, simResponse = {0},   min = 0, max = 1,   default = 0,   table = {[0] = "@i18n(api.RESCUE_PROFILE.tbl_noflip)@", "@i18n(api.RESCUE_PROFILE.tbl_flip)@"}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_flip_mode)@"},
    {field = "rescue_flip_gain",          type = "U8",  apiVersion = 12.06, simResponse = {200}, min = 5, max = 250, default = 200, help = "@i18n(api.RESCUE_PROFILE.help_rescue_flip_gain)@"},
    {field = "rescue_level_gain",         type = "U8",  apiVersion = 12.06, simResponse = {100}, min = 5, max = 250, default = 100, help = "@i18n(api.RESCUE_PROFILE.help_rescue_level_gain)@"},
    {field = "rescue_pull_up_time",       type = "U8",  apiVersion = 12.06, simResponse = {5},   min = 0, max = 250, default = 0.3,  unit = "s", decimals = 1, scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_pull_up_time)@"},
    {field = "rescue_climb_time",         type = "U8",  apiVersion = 12.06, simResponse = {3},   min = 0, max = 250, default = 1, unit = "s", decimals = 1, scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_climb_time)@"},
    {field = "rescue_flip_time",          type = "U8",  apiVersion = 12.06, simResponse = {10},  min = 0, max = 250, default = 2, unit = "s", decimals = 1, scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_flip_time)@"},
    {field = "rescue_exit_time",          type = "U8",  apiVersion = 12.06, simResponse = {5},   min = 0, max = 250, default = 0.5,  unit = "s", decimals = 1, scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_exit_time)@"},
    {field = "rescue_pull_up_collective", type = "U16", apiVersion = 12.06, simResponse = {182, 3}, min = 0, max = 100, default = 65, unit = "%", scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_pull_up_collective)@"},
    {field = "rescue_climb_collective",   type = "U16", apiVersion = 12.06, simResponse = {188, 2}, min = 0, max = 100, default = 45, unit = "%", scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_climb_collective)@"},
    {field = "rescue_hover_collective",   type = "U16", apiVersion = 12.06, simResponse = {194, 1}, min = 0, max = 100, default = 35, unit = "%", scale = 10, help = "@i18n(api.RESCUE_PROFILE.help_rescue_hover_collective)@"},
    {field = "rescue_hover_altitude",     type = "U16", apiVersion = 12.06, simResponse = {244, 1}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_hover_altitude)@", min = 0, max = 500, default = 20, unit = "m"},
    {field = "rescue_alt_p_gain",         type = "U16", apiVersion = 12.06, simResponse = {20, 0}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_p_gain)@", min = 0, max = 1000, default = 20},
    {field = "rescue_alt_i_gain",         type = "U16", apiVersion = 12.06, simResponse = {20, 0}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_i_gain)@", min = 0, max = 1000, default = 20},
    {field = "rescue_alt_d_gain",         type = "U16", apiVersion = 12.06, simResponse = {10, 0}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_d_gain)@", min = 0, max = 1000, default = 10},
    {field = "rescue_max_collective",     type = "U16", apiVersion = 12.06, simResponse = {232, 3}, help = "@i18n(api.RESCUE_PROFILE.help_rescue_max_collective)@", min = 0, max = 100, default = 90, unit = "%", scale = 10},
    {field = "rescue_max_setpoint_rate",  type = "U16", apiVersion = 12.06, simResponse = {44, 1}, min = 5, max = 1000, default = 300, unit = "°/s", help = "@i18n(api.RESCUE_PROFILE.help_rescue_max_setpoint_rate)@"},
    {field = "rescue_max_setpoint_accel", type = "U16", apiVersion = 12.06, simResponse = {184, 11}, min = 0, max = 10000, default = 3000, unit = "°/s^2", help = "@i18n(api.RESCUE_PROFILE.help_rescue_max_setpoint_accel)@"},
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
