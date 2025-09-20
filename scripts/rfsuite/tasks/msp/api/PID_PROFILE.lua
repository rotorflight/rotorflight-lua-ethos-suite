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
local API_NAME = "PID_PROFILE" -- API name (must be same as filename)
local MSP_API_CMD_READ = 94 -- Command identifier 
local MSP_API_CMD_WRITE = 95 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "pid_mode",                        type = "U8", apiVersion = 12.06, simResponse = {3}, help = "@i18n(api.PID_PROFILE.pid_mode)@"},
    {field = "error_decay_time_ground",         type = "U8", apiVersion = 12.06, simResponse = {25},  min = 0,   max = 250, default = 2.5, unit = "s",  decimals = 1, scale = 10, help = "@i18n(api.PID_PROFILE.error_decay_time_ground)@"},
    {field = "error_decay_time_cyclic",         type = "U8", apiVersion = 12.06, simResponse = {250}, min = 0,   max = 250, default = 25, unit = "s",  decimals = 1, scale = 10, help = "@i18n(api.PID_PROFILE.error_decay_time_cyclic)@"},
    {field = "error_decay_time_yaw",            type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.PID_PROFILE.error_decay_time_yaw)@"},
    {field = "error_decay_limit_cyclic",        type = "U8", apiVersion = 12.06, simResponse = {12},  min = 0,   max = 25, default = 12,  unit = "°", help = "@i18n(api.PID_PROFILE.error_decay_limit_cyclic)@"},
    {field = "error_decay_limit_yaw",           type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.PID_PROFILE.error_decay_limit_yaw)@"},
    {field = "error_rotation",                  type = "U8", apiVersion = 12.06, simResponse = {1},   min = 0,   max = 1,   table = {[0] = "@i18n(api.PID_PROFILE.tbl_off)@", "@i18n(api.PID_PROFILE.tbl_on)@"}, help = "@i18n(api.PID_PROFILE.error_rotation)@"},
    {field = "error_limit_0",                   type = "U8", apiVersion = 12.06, simResponse = {30},  min = 0,   max = 180, default = 30,  unit = "°", help = "@i18n(api.PID_PROFILE.error_limit_0)@"},
    {field = "error_limit_1",                   type = "U8", apiVersion = 12.06, simResponse = {30},  min = 0,   max = 180, default = 30,  unit = "°", help = "@i18n(api.PID_PROFILE.error_limit_1)@"},
    {field = "error_limit_2",                   type = "U8", apiVersion = 12.06, simResponse = {45},  min = 0,   max = 180, default = 45,  unit = "°", help = "@i18n(api.PID_PROFILE.error_limit_2)@"},
    {field = "gyro_cutoff_0",                   type = "U8", apiVersion = 12.06, simResponse = {50},  min = 0,   max = 250, default = 50, help = "@i18n(api.PID_PROFILE.gyro_cutoff_0)@"},
    {field = "gyro_cutoff_1",                   type = "U8", apiVersion = 12.06, simResponse = {50},  min = 0,   max = 250, default = 50, help = "@i18n(api.PID_PROFILE.gyro_cutoff_1)@"},
    {field = "gyro_cutoff_2",                   type = "U8", apiVersion = 12.06, simResponse = {100}, min = 0,   max = 250, default = 100, help = "@i18n(api.PID_PROFILE.gyro_cutoff_2)@"},
    {field = "dterm_cutoff_0",                  type = "U8", apiVersion = 12.06, simResponse = {15},  min = 0,   max = 250, default = 15, help = "@i18n(api.PID_PROFILE.dterm_cutoff_0)@"},
    {field = "dterm_cutoff_1",                  type = "U8", apiVersion = 12.06, simResponse = {15},  min = 0,   max = 250, default = 15, help = "@i18n(api.PID_PROFILE.dterm_cutoff_1)@"},
    {field = "dterm_cutoff_2",                  type = "U8", apiVersion = 12.06, simResponse = {20},  min = 0,   max = 250, default = 20, help = "@i18n(api.PID_PROFILE.dterm_cutoff_2)@"},
    {field = "iterm_relax_type",                type = "U8", apiVersion = 12.06, simResponse = {2},   min = 0,   max = 2,   table = {[0] = "@i18n(api.PID_PROFILE.tbl_off)@", "@i18n(api.PID_PROFILE.tbl_rp)@", "@i18n(api.PID_PROFILE.tbl_rpy)@"}, help = "@i18n(api.PID_PROFILE.iterm_relax_type)@"},
    {field = "iterm_relax_cutoff_0",            type = "U8", apiVersion = 12.06, simResponse = {10},  min = 1,   max = 100, default = 10, help = "@i18n(api.PID_PROFILE.iterm_relax_cutoff_0)@"},
    {field = "iterm_relax_cutoff_1",            type = "U8", apiVersion = 12.06, simResponse = {10},  min = 1,   max = 100, default = 10, help = "@i18n(api.PID_PROFILE.iterm_relax_cutoff_1)@"},
    {field = "iterm_relax_cutoff_2",            type = "U8", apiVersion = 12.06, simResponse = {15},  min = 1,   max = 100, default = 10, help = "@i18n(api.PID_PROFILE.iterm_relax_cutoff_2)@"},
    {field = "yaw_cw_stop_gain",                type = "U8", apiVersion = 12.06, simResponse = {100}, min = 25,  max = 250, default = 120, help = "@i18n(api.PID_PROFILE.yaw_cw_stop_gain)@"},
    {field = "yaw_ccw_stop_gain",               type = "U8", apiVersion = 12.06, simResponse = {100}, min = 25,  max = 250, default = 80, help = "@i18n(api.PID_PROFILE.yaw_ccw_stop_gain)@"},
    {field = "yaw_precomp_cutoff",              type = "U8", apiVersion = 12.06, simResponse = {6},   min = 0,   max = 250, default = 5,   unit = "Hz", help = "@i18n(api.PID_PROFILE.yaw_precomp_cutoff)@"},
    {field = "yaw_cyclic_ff_gain",              type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 250, default = 0, help = "@i18n(api.PID_PROFILE.yaw_cyclic_ff_gain)@"},
    {field = "yaw_collective_ff_gain",          type = "U8", apiVersion = 12.06, simResponse = {30},  min = 0,   max = 250, default = 30, help = "@i18n(api.PID_PROFILE.yaw_collective_ff_gain)@"},
    {field = "yaw_collective_dynamic_gain",     type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 125, default = 0, help = "@i18n(api.PID_PROFILE.yaw_collective_dynamic_gain)@"},
    {field = "yaw_collective_dynamic_decay",    type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 250, default = 25,  unit = "s", help = "@i18n(api.PID_PROFILE.yaw_collective_dynamic_decay)@"},
    {field = "pitch_collective_ff_gain",        type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 250, default = 0, help = "@i18n(api.PID_PROFILE.pitch_collective_ff_gain)@"},
    {field = "angle_level_strength",            type = "U8", apiVersion = 12.06, simResponse = {40},  min = 0,   max = 200, default = 40, help = "@i18n(api.PID_PROFILE.angle_level_strength)@"},
    {field = "angle_level_limit",               type = "U8", apiVersion = 12.06, simResponse = {55},  min = 10,  max = 90,  default = 55,  unit = "°", help = "@i18n(api.PID_PROFILE.angle_level_limit)@"},
    {field = "horizon_level_strength",          type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 200, default = 40, help = "@i18n(api.PID_PROFILE.horizon_level_strength)@"},
    {field = "trainer_gain",                    type = "U8", apiVersion = 12.06, simResponse = {75},  min = 25,  max = 255, default = 75, help = "@i18n(api.PID_PROFILE.trainer_gain)@"},
    {field = "trainer_angle_limit",             type = "U8", apiVersion = 12.06, simResponse = {20},  min = 10,  max = 80,  default = 20,  unit = "°", help = "@i18n(api.PID_PROFILE.trainer_angle_limit)@"},
    {field = "cyclic_cross_coupling_gain",      type = "U8", apiVersion = 12.06, simResponse = {25},  min = 0,   max = 250, default = 50, help = "@i18n(api.PID_PROFILE.cyclic_cross_coupling_gain)@"},
    {field = "cyclic_cross_coupling_ratio",     type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 200, default = 0,   unit = "%", help = "@i18n(api.PID_PROFILE.cyclic_cross_coupling_ratio)@"},
    {field = "cyclic_cross_coupling_cutoff",    type = "U8", apiVersion = 12.06, simResponse = {15},  min = 1,   max = 250, default = 2.5, unit = "Hz", scale = 10, decimals = 1, help = "@i18n(api.PID_PROFILE.cyclic_cross_coupling_cutoff)@"},
    {field = "offset_limit_0",                  type = "U8", apiVersion = 12.06, simResponse = {45},  min = 0,   max = 180, default = 45,  unit = "°", help = "@i18n(api.PID_PROFILE.offset_limit_0)@"},
    {field = "offset_limit_1",                  type = "U8", apiVersion = 12.06, simResponse = {45},  min = 0,   max = 180, default = 45,  unit = "°", help = "@i18n(api.PID_PROFILE.offset_limit_1)@"},
    {field = "bterm_cutoff_0",                  type = "U8", apiVersion = 12.06, simResponse = {15},  min = 0,   max = 250, default = 15, help = "@i18n(api.PID_PROFILE.bterm_cutoff_0)@"},
    {field = "bterm_cutoff_1",                  type = "U8", apiVersion = 12.06, simResponse = {15},  min = 0,   max = 250, default = 15, help = "@i18n(api.PID_PROFILE.bterm_cutoff_1)@"},
    {field = "bterm_cutoff_2",                  type = "U8", apiVersion = 12.06, simResponse = {20},  min = 0,   max = 250, default = 20, help = "@i18n(api.PID_PROFILE.bterm_cutoff_2)@"},
    {field = "yaw_inertia_precomp_gain",        type = "U8", apiVersion = 12.08, simResponse = {10},  min = 0,   max = 250, default = 0, help = "@i18n(api.PID_PROFILE.yaw_inertia_precomp_gain)@"},
    {field = "yaw_inertia_precomp_cutoff",      type = "U8", apiVersion = 12.08, simResponse = {20},  min = 0,   max = 250, default = 2.5,  scale = 10, decimals = 1, unit = "Hz", help = "@i18n(api.PID_PROFILE.yaw_inertia_precomp_cutoff)@"},
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
