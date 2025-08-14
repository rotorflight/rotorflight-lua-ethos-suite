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
local API_NAME = "ESC_PARAMETERS_FLYROTOR" -- API name (must be same as filename)
local MSP_API_CMD_READ = 217 -- Command identifier 
local MSP_API_CMD_WRITE = 218 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 
local MSP_SIGNATURE = 0x73
local MSP_HEADER_BYTES = 2

local tblLed = {
    "CUSTOM",
    "BLACK",
    "RED",
    "GREEN",
    "BLUE",
    "YELLOW",
    "MAGENTA",
    "CYAN",
    "WHITE",
    "ORANGE",
    "GRAY",
    "MAROON",
    "DARK_GREEN",
    "NAVY",
    "PURPLE",
    "TEAL",
    "SILVER",
    "PINK",
    "GOLD",
    "BROWN",
    "LIGHT_BLUE",
    "FL_PINK",
    "FL_ORANGE",
    "FL_LIME",
    "FL_MINT",
    "FL_CYAN",
    "FL_PURPLE",
    "FL_HOT_PINK",
    "FL_LIGHT_YELLOW",
    "FL_AQUAMARINE",
    "FL_GOLD",
    "FL_DEEP_PINK",
    "FL_NEON_GREEN",
    "FL_ORANGE_RED"
}

local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",           type = "U8",  apiVersion = 12.07, simResponse = {115}},
    {field = "esc_command",             type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "esc_type",                type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "esc_model",               type = "U16", apiVersion = 12.07, simResponse = {1, 24}},
    {field = "esc_sn",                  type = "U64", apiVersion = 12.07, simResponse = {231, 79, 190, 216, 78, 29, 169, 244}},
    {field = "esc_iap",                 type = "U24", apiVersion = 12.07, simResponse = {1, 0, 0}},
    {field = "esc_fw",                  type = "U24", apiVersion = 12.07, simResponse = {1, 0, 1}},
    {field = "esc_hardware",            type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "throttle_min",            type = "U16", apiVersion = 12.07, simResponse = {4, 76},       byteorder = "big"},
    {field = "throttle_max",            type = "U16", apiVersion = 12.07, simResponse = {7, 148},      byteorder = "big"},
    {field = "governor",                type = "U8",  apiVersion = 12.07, simResponse = {0},           table = {rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_extgov"), rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_escgov")}, tableIdxInc = -1},
    {field = "cell_count",              type = "U8",  apiVersion = 12.07, simResponse = {6},           min = 4, max = 14, default = 6},
    {field = "low_voltage_protection",  type = "U8",  apiVersion = 12.07, simResponse = {30},          min = 28, max = 38, scale = 10, default = 30, decimals = 1, unit = "V"},
    {field = "temperature_protection",  type = "U8",  apiVersion = 12.07, simResponse = {125},         min = 50, max = 135, default = 125, unit = "°"},
    {field = "bec_voltage",             type = "U8",  apiVersion = 12.07, simResponse = {1},           table = {rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_disabled"), "7.5V", "8.0V", "8.5V", "12.0V"}, tableIdxInc = -1},
    {field = "timing_angle",            type = "U8",  apiVersion = 12.07, simResponse = {0},           table = {rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_auto"),"1°","2°","3°","4°","5°","6°","7°","8°","9°","10°"}, tableIdxInc = -1},
    {field = "motor_direction",         type = "U8",  apiVersion = 12.07, simResponse = {0},           table = {rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_cw"), rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_ccw")}, tableIdxInc = -1},
    {field = "starting_torque",         type = "U8",  apiVersion = 12.07, simResponse = {3},           min = 1, max = 15, default = 3},
    {field = "response_speed",          type = "U8",  apiVersion = 12.07, simResponse = {5},           min = 1, max = 15, default = 5},
    {field = "buzzer_volume",           type = "U8",  apiVersion = 12.07, simResponse = {1},           min = 1, max = 5, default = 2},
    {field = "current_gain",            type = "S8",  apiVersion = 12.07, simResponse = {20},          min = 0, max = 40, default = 20, offset = -20},
    {field = "fan_control",             type = "U8",  apiVersion = 12.07, simResponse = {0},           table = {rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_automatic"), rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_alwayson")}, tableIdxInc = -1},
    {field = "soft_start",              type = "U8",  apiVersion = 12.07, simResponse = {15},          min = 5, max = 55},
    {field = "gov_p",                   type = "U16", apiVersion = 12.07, simResponse = {0, 45},       min = 0, max = 100, default = 45, byteorder = "big"},
    {field = "gov_i",                   type = "U16", apiVersion = 12.07, simResponse = {0, 35},       min = 0, max = 100, default = 35,  byteorder = "big"},
    {field = "gov_d",                   type = "U16", apiVersion = 12.07, simResponse = {0, 0},        min = 0, max = 100, default = 0,  byteorder = "big"},
    {field = "motor_erpm_max",          type = "U24", apiVersion = 12.07, simResponse = {2, 23, 40},   min = 0, max = 1000000, step = 100, byteorder = "big"},
    {field = "throttle_protocol",       type = "U8",  apiVersion = 12.08, simResponse = {0},           min = 0, max = 1, table = {"PWM", "RESERVE"}, tableIdxInc = -1},
    {field = "telemetry_protocol",      type = "U8",  apiVersion = 12.08, simResponse = {0},           min = 0, max = 0, table = {"FLYROTOR"}, tableIdxInc = -1},
    {field = "led_color_index",         type = "U8",  apiVersion = 12.08, simResponse = {3},           min = 0, max = #tblLed - 1, table = tblLed, tableIdxInc = -1},
    {field = "led_color_rgb",           type = "U24", apiVersion = 12.08, simResponse = {0, 0, 0}},
    {field = "motor_temp_sensor",       type = "U8",  apiVersion = 12.08, simResponse = {0},           min = 0, max = 1, table={rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_disabled"), rfsuite.i18n.get("api.ESC_PARAMETERS_FLYROTOR.tbl_enabled")}, tableIdxInc = -1},
    {field = "motor_temp",              type = "U8",  apiVersion = 12.08, simResponse = {100},         min = 50, max = 150, unit = "°"},
    {field = "battery_capacity",        type = "U16", apiVersion = 12.08, simResponse = {0, 0},        min = 0, max = 10000, step = 100, unit = "mAh", byteorder = "big"},
}

-- Process structure in one pass
local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE =
    rfsuite.tasks.msp.api.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- set read structure
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local function processedData()
    rfsuite.utils.log("Processed data","debug")

end

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
