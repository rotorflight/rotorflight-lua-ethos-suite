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
local API_NAME = "ESC_PARAMETERS_AM32" -- API name (must be same as filename)
local MSP_API_CMD_READ = 217 -- Command identifier 
local MSP_API_CMD_WRITE = 218 -- Command identifier 
local MSP_SIGNATURE = 0xC2 -- MSP signature
local MSP_HEADER_BYTES = 2

-- tables used in structure below
local motorDirection = {"normal", "reversed"}
local timingAdvance = {"0°", "7.5°", "15°", "22.5°"}
local onOff = {"off", "on"}
local protocol = {"Auto", "Dshot 300-600", "Servo 1-2ms", "Serial", "BF Safe Arming"}

-- api structure
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",             type = "U8",  apiVersion = 12.07, simResponse = {194}},
    {field = "esc_command",               type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "boot_byte",                 type = "U8",  apiVersion = 12.07, simResponse = {1}},
    {field = "layout_revision",           type = "U8",  apiVersion = 12.07, simResponse = {2}},
    {field = "boot_loader_revision",      type = "U8",  apiVersion = 12.07, simResponse = {13}},
    {field = "main_revision",             type = "U8",  apiVersion = 12.07, simResponse = {2}},
    {field = "sub_revision",              type = "U8",  apiVersion = 12.07, simResponse = {17}},
    {field = "name",                      type = "U96", apiVersion = 12.07, simResponse = {86,105,109,100,114,111,110,101,76,52,51,49,0,0,0}}, -- string
    {field = "motor_direction",           type = "U8",  apiVersion = 12.07, simResponse = {0}, tableIdxInc = -1, table = motorDirection},
    {field = "bidirectional_mode",        type = "U8",  apiVersion = 12.07, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "sinusoidal_startup",        type = "U8",  apiVersion = 12.07, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "complementary_pwm",         type = "U8",  apiVersion = 12.07, simResponse = {1}, tableIdxInc = -1, table = onOff},
    {field = "variable_pwm_frequency",    type = "U8",  apiVersion = 12.07, simResponse = {1}, tableIdxInc = -1, table = onOff},
    {field = "stuck_rotor_protection",    type = "U8",  apiVersion = 12.07, simResponse = {1}, tableIdxInc = -1, table = onOff},
    {field = "timing_advance",            type = "U8",  apiVersion = 12.07, simResponse = {2}, tableIdxInc = -1, table = timingAdvance}, -- *7.5
    {field = "pwm_frequency",             type = "U8",  apiVersion = 12.07, simResponse = {24}},
    {field = "startup_power",             type = "U8",  apiVersion = 12.07, simResponse = {150}, default = 100, min = 50, max = 150},
    {field = "motor_kv",                  type = "U8",  apiVersion = 12.07, simResponse = {107}}, -- *40+20
    {field = "motor_poles",               type = "U8",  apiVersion = 12.07, simResponse = {14}, default = 14, min = 2, max = 36},
    {field = "brake_on_stop",             type = "U8",  apiVersion = 12.07, simResponse = {1}, tableIdxInc = -1, table = onOff},
    {field = "stall_protection",          type = "U8",  apiVersion = 12.07, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "beep_volume",               type = "U8",  apiVersion = 12.07, simResponse = {10}, default = 10, min = 0, max = 11},
    {field = "interval_telemetry",        type = "U8",  apiVersion = 12.07, simResponse = {0}, tableIdxInc = -1, table = onOff},
    {field = "servo_low_threshold",       type = "U8",  apiVersion = 12.07, simResponse = {128}},
    {field = "servo_high_threshold",      type = "U8",  apiVersion = 12.07, simResponse = {128}},
    {field = "servo_neutral",             type = "U8",  apiVersion = 12.07, simResponse = {128}},
    {field = "servo_dead_band",           type = "U8",  apiVersion = 12.07, simResponse = {50}},
    {field = "low_voltage_cutoff",        type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "low_voltage_threshold",     type = "U8",  apiVersion = 12.07, simResponse = {50}},
    {field = "rc_car_reversing",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "use_hall_sensors",          type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "sine_mode_range",           type = "U8",  apiVersion = 12.07, simResponse = {15}},
    {field = "brake_strength",            type = "U8",  apiVersion = 12.07, simResponse = {10}, default = 0, min = 0, max = 10},
    {field = "running_brake_level",       type = "U8",  apiVersion = 12.07, simResponse = {10}, default = 0, min = 0, max = 10},
    {field = "temperature_limit",         type = "U8",  apiVersion = 12.07, simResponse = {145}},
    {field = "current_limit",             type = "U8",  apiVersion = 12.07, simResponse = {102}},
    {field = "sine_mode_power",           type = "U8",  apiVersion = 12.07, simResponse = {6}},
    {field = "esc_protocol",              type = "U8",  apiVersion = 12.07, simResponse = {1}, tableIdxInc = -1, table = protocol},
    {field = "auto_advance",              type = "U8",  apiVersion = 12.07, simResponse = {0},tableIdxInc = -1, table = onOff}
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
    setTimeout = setTimeout,
    mspSignature = MSP_SIGNATURE,
    mspHeaderBytes = MSP_HEADER_BYTES,
    simulatorResponse = MSP_API_SIMULATOR_RESPONSE
}