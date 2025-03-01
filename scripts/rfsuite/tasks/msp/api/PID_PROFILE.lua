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

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "pid_mode",                        type = "U8", apiVersion = 12.06, simResponse = {3}},
    {field = "error_decay_time_ground",         type = "U8", apiVersion = 12.06, simResponse = {25},  min = 0,   max = 250, default = 250, unit = "s",  decimals = 1, scale = 10, help = "Bleeds off the current controller error when the craft is not airborne to stop the craft tipping over."},
    {field = "error_decay_time_cyclic",         type = "U8", apiVersion = 12.06, simResponse = {250}, min = 0,   max = 250, default = 180, unit = "s",  decimals = 1, scale = 10, help = "Time constant for bleeding off cyclic I-term. Higher will stabilize hover, lower will drift."},
    {field = "error_decay_time_yaw",            type = "U8", apiVersion = 12.06, simResponse = {0}},
    {field = "error_decay_limit_cyclic",        type = "U8", apiVersion = 12.06, simResponse = {12},  min = 0,   max = 250, default = 20,  unit = "°", help = "Maximum bleed-off speed for cyclic I-term."},
    {field = "error_decay_limit_yaw",           type = "U8", apiVersion = 12.06, simResponse = {0}},
    {field = "error_rotation",                  type = "U8", apiVersion = 12.06, simResponse = {1},   min = 0,   max = 1,   table = {[0] = "OFF", "ON"}, help = "Rotates the current roll and pitch error terms around yaw when the craft rotates. This is sometimes called Piro Compensation."},
    {field = "error_limit_0",                   type = "U8", apiVersion = 12.06, simResponse = {30},  min = 0,   max = 180, default = 30,  unit = "°", help = "Hard limit for the angle error in the PID loop. The absolute error and thus the I-term will never go above these limits."},
    {field = "error_limit_1",                   type = "U8", apiVersion = 12.06, simResponse = {30},  min = 0,   max = 180, default = 30,  unit = "°", help = "Hard limit for the angle error in the PID loop. The absolute error and thus the I-term will never go above these limits."},
    {field = "error_limit_2",                   type = "U8", apiVersion = 12.06, simResponse = {45},  min = 0,   max = 180, default = 45,  unit = "°", help = "Hard limit for the angle error in the PID loop. The absolute error and thus the I-term will never go above these limits."},
    {field = "gyro_cutoff_0",                   type = "U8", apiVersion = 12.06, simResponse = {50},  min = 0,   max = 250, default = 50,  help = "PID loop overall bandwidth in Hz."},
    {field = "gyro_cutoff_1",                   type = "U8", apiVersion = 12.06, simResponse = {50},  min = 0,   max = 250, default = 50,  help = "PID loop overall bandwidth in Hz."},
    {field = "gyro_cutoff_2",                   type = "U8", apiVersion = 12.06, simResponse = {100}, min = 0,   max = 250, default = 100, help = "PID loop overall bandwidth in Hz."},
    {field = "dterm_cutoff_0",                  type = "U8", apiVersion = 12.06, simResponse = {15},  min = 0,   max = 250, default = 15,  help = "D-term cutoff in Hz."},
    {field = "dterm_cutoff_1",                  type = "U8", apiVersion = 12.06, simResponse = {15},  min = 0,   max = 250, default = 15,  help = "D-term cutoff in Hz."},
    {field = "dterm_cutoff_2",                  type = "U8", apiVersion = 12.06, simResponse = {20},  min = 0,   max = 250, default = 20,  help = "D-term cutoff in Hz."},
    {field = "iterm_relax_type",                type = "U8", apiVersion = 12.06, simResponse = {2},   min = 0,   max = 2,   table = {[0] = "OFF", "RP", "RPY"}, help = "Choose the axes in which this is active. RP: Roll, Pitch. RPY: Roll, Pitch, Yaw."},
    {field = "iterm_relax_cutoff_0",            type = "U8", apiVersion = 12.06, simResponse = {10},  min = 1,   max = 100, default = 10,  help = "Helps reduce bounce back after fast stick movements. Can cause inconsistency in small stick movements if too low."},
    {field = "iterm_relax_cutoff_1",            type = "U8", apiVersion = 12.06, simResponse = {10},  min = 1,   max = 100, default = 10,  help = "Helps reduce bounce back after fast stick movements. Can cause inconsistency in small stick movements if too low."},
    {field = "iterm_relax_cutoff_2",            type = "U8", apiVersion = 12.06, simResponse = {15},  min = 1,   max = 100, default = 10,  help = "Helps reduce bounce back after fast stick movements. Can cause inconsistency in small stick movements if too low."},
    {field = "yaw_cw_stop_gain",                type = "U8", apiVersion = 12.06, simResponse = {100}, min = 25,  max = 250, default = 80,  help = "Stop gain (PD) for clockwise rotation."},
    {field = "yaw_ccw_stop_gain",               type = "U8", apiVersion = 12.06, simResponse = {100}, min = 25,  max = 250, default = 120, help = "Stop gain (PD) for counter-clockwise rotation."},
    {field = "yaw_precomp_cutoff",              type = "U8", apiVersion = 12.06, simResponse = {6},   min = 0,   max = 250, default = 5,   unit = "Hz", help = "Frequency limit for all yaw precompensation actions."},
    {field = "yaw_cyclic_ff_gain",              type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 250, default = 30,  help = "Cyclic feedforward mixed into yaw (cyclic-to-yaw precomp)."},
    {field = "yaw_collective_ff_gain",          type = "U8", apiVersion = 12.06, simResponse = {30},  min = 0,   max = 250, default = 0,   help = "Collective feedforward mixed into yaw (collective-to-yaw precomp)."},
    {field = "yaw_collective_dynamic_gain",     type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 250, default = 0,   help = "An extra boost of yaw precomp on collective input."},
    {field = "yaw_collective_dynamic_decay",    type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 250, default = 25,  unit = "s",  help = "Decay time for the extra yaw precomp on collective input."},
    {field = "pitch_collective_ff_gain",        type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 250, default = 0,   help = "Increasing will compensate for the pitching up motion caused by tail drag when climbing."},
    {field = "angle_level_strength",            type = "U8", apiVersion = 12.06, simResponse = {40},  min = 0,   max = 200, default = 40,  help = "Determines how aggressively the helicopter tilts back to level while in Angle Mode."},
    {field = "angle_level_limit",               type = "U8", apiVersion = 12.06, simResponse = {55},  min = 10,  max = 90,  default = 55,  unit = "°", help = "Limit the maximum angle the helicopter will pitch/roll to while in Angle mode."},
    {field = "horizon_level_strength",          type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 200, default = 40,  help = "Determines how aggressively the helicopter tilts back to level while in Horizon Mode."},
    {field = "trainer_gain",                    type = "U8", apiVersion = 12.06, simResponse = {75},  min = 25,  max = 255, default = 75,  help = "Determines how aggressively the helicopter tilts back to the maximum angle (if exceeded) while in Acro Trainer Mode."},
    {field = "trainer_angle_limit",             type = "U8", apiVersion = 12.06, simResponse = {20},  min = 10,  max = 80,  default = 20,  unit = "°", help = "Limit the maximum angle the helicopter will pitch/roll to while in Acro Trainer Mode."},
    {field = "cyclic_cross_coupling_gain",      type = "U8", apiVersion = 12.06, simResponse = {25},  min = 0,   max = 250, default = 50,  help = "Amount of compensation applied for pitch-to-roll decoupling."},
    {field = "cyclic_cross_coupling_ratio",     type = "U8", apiVersion = 12.06, simResponse = {0},   min = 0,   max = 200, default = 0,   unit = "%", help = "Amount of roll-to-pitch compensation needed, vs. pitch-to-roll."},
    {field = "cyclic_cross_coupling_cutoff",    type = "U8", apiVersion = 12.06, simResponse = {15},  min = 1,   max = 250, default = 2.5, unit = "Hz", scale = 10, decimals = 1, help = "Frequency limit for the compensation. Higher value will make the compensation action faster."},
    {field = "offset_limit_0",                  type = "U8", apiVersion = 12.06, simResponse = {45},  min = 0,   max = 180, default = 45,  unit = "°", help = "Hard limit for the High Speed Integral offset angle in the PID loop. The O-term will never go over these limits."},
    {field = "offset_limit_1",                  type = "U8", apiVersion = 12.06, simResponse = {45},  min = 0,   max = 180, default = 45,  unit = "°", help = "Hard limit for the High Speed Integral offset angle in the PID loop. The O-term will never go over these limits."},
    {field = "bterm_cutoff_0",                  type = "U8", apiVersion = 12.06, simResponse = {15},  min = 0,   max = 250, default = 15,  help = "B-term cutoff in Hz."},
    {field = "bterm_cutoff_1",                  type = "U8", apiVersion = 12.06, simResponse = {15},  min = 0,   max = 250, default = 15,  help = "B-term cutoff in Hz."},
    {field = "bterm_cutoff_2",                  type = "U8", apiVersion = 12.06, simResponse = {20},  min = 0,   max = 250, default = 20,  help = "B-term cutoff in Hz."},
    {field = "yaw_inertia_precomp_gain",        type = "U8", apiVersion = 12.08, simResponse = {10},  min = 0,   max = 250, default = 0,   help = "Scalar gain. The strength of the main rotor inertia. Higher value means more precomp is applied to yaw control."},
    {field = "yaw_inertia_precomp_cutoff",      type = "U8", apiVersion = 12.08, simResponse = {20},  min = 0,   max = 250, default = 25,  unit = "Hz", help = "Cutoff. Derivative cutoff frequency in 1/10Hz steps. Controls how sharp the precomp is. Higher value is sharper."},
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
            mspData = rfsuite.tasks.msp.api.parseMSPData(buf, MSP_API_STRUCTURE_READ)
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
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = suppliedPayload or rfsuite.tasks.msp.api.buildWritePayload(API_NAME, payloadData,MSP_API_STRUCTURE_WRITE),
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
