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
local MSP_REBUILD_ON_WRITE = true -- Rebuild the payload on write  - keep true as we use bitmap for flags
local MSP_SIGNATURE = 0xA5
local MSP_HEADER_BYTES = 2

-- tables used in structure below
local escMode = {rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_modefree"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_modeext"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_modeheli"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_modestore"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_modeglider"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_modeair"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_modef3a")}
local direction = {rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_normal"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_reverse")}
local cuttoff = {rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_off"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_slowdown"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_cutoff")}
local cuttoffVoltage = {"2.9 V", "3.0 V", "3.1 V", "3.2 V", "3.3 V", "3.4 V"}
local offOn = {rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_off"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_on")}
local startupResponse = {rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_normal"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_smooth")}
local throttleResponse = {rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_slow"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_medium"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_fast"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_custom")}
local motorTiming = {rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_autonorm"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_autoefficient"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_autopower"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_autoextreme"), "0°", "6°", "12°", "18°", "24°", "30°"}
local motorTimingToUI = {0, 4, 5, 6, 7, 8, 9, [16] = 0, [17] = 1, [18] = 2, [19] = 3}
local motorTimingFromUI = {0, 17, 18, 19, 1, 2, 3, 4, 5, 6}
local freewheel = {rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_off"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_auto"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_unused"), rfsuite.i18n.get("api.ESC_PARAMETERS_YGE.tbl_alwayson")}


local flags_bitmap = {
    {field = "direction", tableIdxInc = -1, table = direction},
    {field = "f3cauto", tableIdxInc = -1, table = offOn},
    {field = "keepmah", tableIdxInc = -1, table = offOn},
    {field = "bec12v", tableIdxInc = -1, table = offOn},
}

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",      type = "U8",  apiVersion = 12.07, simResponse = {165}},
    {field = "esc_command",        type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "esc_model",          type = "U8",  apiVersion = 12.07, simResponse = {32}},
    {field = "esc_version",        type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "governor",           type = "U16", apiVersion = 12.07, simResponse = {3, 0},  min = 1, max = #escMode, table = escMode, tableIdxInc = -1},
    {field = "lv_bec_voltage",     type = "U16", apiVersion = 12.07, simResponse = {55, 0}, unit = "v", min = 55, max = 84, scale = 10, decimals = 1},
    {field = "timing",             type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = #motorTiming, tableIdxInc = -1, table = motorTiming},
    {field = "acceleration",       type = "U16", apiVersion = 12.07, simResponse = {0, 0}},
    {field = "gov_p",              type = "U16", apiVersion = 12.07, simResponse = {4, 0},min = 1, max = 10},
    {field = "gov_i",              type = "U16", apiVersion = 12.07, simResponse = {3, 0},min = 1, max = 10},
    {field = "throttle_response",  type = "U16", apiVersion = 12.07, simResponse = {1, 0}, min = 0, max = #throttleResponse, tableIdxInc = -1, table = throttleResponse},
    {field = "auto_restart_time",  type = "U16", apiVersion = 12.07, simResponse = {1, 0},  min = 0, max = #cuttoff, tableIdxInc = -1, table = cuttoff},
    {field = "cell_cutoff",        type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 0, max = #cuttoffVoltage, tableIdxInc = -1, table = cuttoffVoltage},
    {field = "active_freewheel",   type = "U16", apiVersion = 12.07, simResponse = {3, 0},min = 0, max = #freewheel, tableIdxInc = -1, table = freewheel},
    {field = "esc_type",           type = "U16", apiVersion = 12.07, simResponse = {80, 3}},
    {field = "firmware_version",   type = "U32", apiVersion = 12.07, simResponse = {131, 148, 1, 0}},
    {field = "serial_number",      type = "U32", apiVersion = 12.07, simResponse = {30, 170,0,0}},
    {field = "unknown_1",          type = "U16", apiVersion = 12.07, simResponse = {3, 0}},
    {field = "stick_zero_us",      type = "U16", apiVersion = 12.07, simResponse = {86, 4} ,min = 900, max = 1900, unit = "us"},
    {field = "stick_range_us",     type = "U16", apiVersion = 12.07, simResponse = {22, 3}, min = 600, max = 1500, unit = "us"},
    {field = "unknown_2",          type = "U16", apiVersion = 12.07, simResponse = {163, 15}},
    {field = "motor_poll_pairs",   type = "U16", apiVersion = 12.07, simResponse = {1, 0}, min = 1, max = 100},
    {field = "pinion_teeth",       type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 1, max = 255},
    {field = "main_teeth",         type = "U16", apiVersion = 12.07, simResponse = {2, 0}, min = 1, max = 1800},
    {field = "min_start_power",    type = "U16", apiVersion = 12.07, simResponse = {20, 0}, min = 0, max = 26, unit = "%"},
    {field = "max_start_power",    type = "U16", apiVersion = 12.07, simResponse = {20, 0}, min = 0, max = 31, unit = "%"},
    {field = "unknown_3",          type = "U16", apiVersion = 12.07, simResponse = {0, 0}},
    {field = "flags",              type = "U8",  apiVersion = 12.07, simResponse = {0}, bitmap = flags_bitmap},
    {field = "unknown_4",          type = "U8",  apiVersion = 12.07, simResponse = {0}, min = 0, max = 1, tableIdxInc = -1, table = offOn},
    {field = "current_limit",      type = "U16", apiVersion = 12.07, simResponse = {2, 19},  unit="A", min = 1, max = 65500, decimals = 2, scale = 100},
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
