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
local API_NAME = "ESC_PARAMETERS_YGE" -- API name (must be same as filename)
local MSP_API_CMD_READ = 217 -- Command identifier 
local MSP_API_CMD_WRITE = 218 -- Command identifier
local MSP_REBUILD_ON_WRITE = false 
local MSP_SIGNATURE = 0xA5
local MSP_HEADER_BYTES = 2

-- tables used in structure below
local escMode = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_modefree)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeext)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeheli)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modestore)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeglider)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modeair)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_modef3a)@"}
local direction = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_reverse)@"}
local cuttoff = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_slowdown)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_cutoff)@"}
local cuttoffVoltage = {"2.9 V", "3.0 V", "3.1 V", "3.2 V", "3.3 V", "3.4 V"}
local offOn = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_on)@"}
local startupResponse = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_normal)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_smooth)@"}
local throttleResponse = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_slow)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_medium)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_fast)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_custom)@"}
local motorTiming = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_autonorm)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autoefficient)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autopower)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_autoextreme)@", "0°", "6°", "12°", "18°", "24°", "30°"}
local motorTimingToUI = {0, 4, 5, 6, 7, 8, 9, [16] = 0, [17] = 1, [18] = 2, [19] = 3}
local motorTimingFromUI = {0, 17, 18, 19, 1, 2, 3, 4, 5, 6}
local freewheel = {"@i18n(api.ESC_PARAMETERS_YGE.tbl_off)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_auto)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_unused)@", "@i18n(api.ESC_PARAMETERS_YGE.tbl_alwayson)@"}


local flags_bitmap = {
    {field = "direction", tableIdxInc = -1, table = direction},
    {field = "f3cauto", tableIdxInc = -1, table = offOn},
    {field = "keepmah", tableIdxInc = -1, table = offOn},
    {field = "bec12v", tableIdxInc = -1, table = offOn},
}

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",      type = "U8",  apiVersion = 12.07, simResponse = {165}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_signature)@"},
    {field = "esc_command",        type = "U8",  apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_command)@"},
    {field = "esc_model",          type = "U8",  apiVersion = 12.07, simResponse = {32}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_model)@"},
    {field = "esc_version",        type = "U8",  apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_version)@"},
    {field = "governor",           type = "U16", apiVersion = 12.07, simResponse = {3, 0},  min = 1, max = #escMode, table = escMode, tableIdxInc = -1, help = "@i18n(api.ESC_PARAMETERS_YGE.governor)@"},
    {field = "lv_bec_voltage",     type = "U16", apiVersion = 12.07, simResponse = {55, 0}, unit = "v", min = 55, max = 84, scale = 10, decimals = 1, help = "@i18n(api.ESC_PARAMETERS_YGE.lv_bec_voltage)@"},
    {field = "timing",             type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = #motorTiming, tableIdxInc = -1, table = motorTiming, help = "@i18n(api.ESC_PARAMETERS_YGE.timing)@"},
    {field = "acceleration",       type = "U16", apiVersion = 12.07, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.acceleration)@"},
    {field = "gov_p",              type = "U16", apiVersion = 12.07, simResponse = {4, 0},min = 1, max = 10, help = "@i18n(api.ESC_PARAMETERS_YGE.gov_p)@"},
    {field = "gov_i",              type = "U16", apiVersion = 12.07, simResponse = {3, 0},min = 1, max = 10, help = "@i18n(api.ESC_PARAMETERS_YGE.gov_i)@"},
    {field = "throttle_response",  type = "U16", apiVersion = 12.07, simResponse = {1, 0}, min = 0, max = #throttleResponse, tableIdxInc = -1, table = throttleResponse, help = "@i18n(api.ESC_PARAMETERS_YGE.throttle_response)@"},
    {field = "auto_restart_time",  type = "U16", apiVersion = 12.07, simResponse = {1, 0},  min = 0, max = #cuttoff, tableIdxInc = -1, table = cuttoff, help = "@i18n(api.ESC_PARAMETERS_YGE.auto_restart_time)@"},
    {field = "cell_cutoff",        type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 0, max = #cuttoffVoltage, tableIdxInc = -1, table = cuttoffVoltage, help = "@i18n(api.ESC_PARAMETERS_YGE.cell_cutoff)@"},
    {field = "active_freewheel",   type = "U16", apiVersion = 12.07, simResponse = {3, 0},min = 0, max = #freewheel, tableIdxInc = -1, table = freewheel, help = "@i18n(api.ESC_PARAMETERS_YGE.active_freewheel)@"},
    {field = "esc_type",           type = "U16", apiVersion = 12.07, simResponse = {80, 3}, help = "@i18n(api.ESC_PARAMETERS_YGE.esc_type)@"},
    {field = "firmware_version",   type = "U32", apiVersion = 12.07, simResponse = {131, 148, 1, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.firmware_version)@"},
    {field = "serial_number",      type = "U32", apiVersion = 12.07, simResponse = {30, 170,0,0}, help = "@i18n(api.ESC_PARAMETERS_YGE.serial_number)@"},
    {field = "unknown_1",          type = "U16", apiVersion = 12.07, simResponse = {3, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.unknown_1)@"},
    {field = "stick_zero_us",      type = "U16", apiVersion = 12.07, simResponse = {86, 4} ,min = 900, max = 1900, unit = "us", help = "@i18n(api.ESC_PARAMETERS_YGE.stick_zero_us)@"},
    {field = "stick_range_us",     type = "U16", apiVersion = 12.07, simResponse = {22, 3}, min = 600, max = 1500, unit = "us", help = "@i18n(api.ESC_PARAMETERS_YGE.stick_range_us)@"},
    {field = "unknown_2",          type = "U16", apiVersion = 12.07, simResponse = {163, 15}, help = "@i18n(api.ESC_PARAMETERS_YGE.unknown_2)@"},
    {field = "motor_poll_pairs",   type = "U16", apiVersion = 12.07, simResponse = {1, 0}, min = 1, max = 100, help = "@i18n(api.ESC_PARAMETERS_YGE.motor_poll_pairs)@"},
    {field = "pinion_teeth",       type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 1, max = 255, help = "@i18n(api.ESC_PARAMETERS_YGE.pinion_teeth)@"},
    {field = "main_teeth",         type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 1, max = 1800, help = "@i18n(api.ESC_PARAMETERS_YGE.main_teeth)@"},
    {field = "min_start_power",    type = "U16", apiVersion = 12.07, simResponse = {20, 0}, min = 0, max = 26, unit = "%", help = "@i18n(api.ESC_PARAMETERS_YGE.min_start_power)@"},
    {field = "max_start_power",    type = "U16", apiVersion = 12.07, simResponse = {20, 0}, min = 0, max = 31, unit = "%", help = "@i18n(api.ESC_PARAMETERS_YGE.max_start_power)@"},
    {field = "unknown_3",          type = "U16", apiVersion = 12.07, simResponse = {0, 0}, help = "@i18n(api.ESC_PARAMETERS_YGE.unknown_3)@"},
    {field = "flags",              type = "U8",  apiVersion = 12.07, simResponse = {0}, bitmap = flags_bitmap, help = "@i18n(api.ESC_PARAMETERS_YGE.flags)@"},
    {field = "unknown_4",          type = "U8",  apiVersion = 12.07, simResponse = {0}, min = 0, max = 1, tableIdxInc = -1, table = offOn, help = "@i18n(api.ESC_PARAMETERS_YGE.unknown_4)@"},
    {field = "current_limit",      type = "U16", apiVersion = 12.07, simResponse = {2, 19},  unit="A", min = 1, max = 65500, decimals = 2, scale = 100, help = "@i18n(api.ESC_PARAMETERS_YGE.current_limit)@"},
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
