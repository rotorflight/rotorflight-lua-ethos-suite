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
local API_NAME = "ESC_PARAMETERS_XDFLY" -- API name (must be same as filename)
local MSP_API_CMD_READ = 217 -- Command identifier 
local MSP_API_CMD_WRITE = 218 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 
local MSP_SIGNATURE = 0xA6
local MSP_HEADER_BYTES = 2

-- tables used in structure below
local flightMode = {"Helicopter", "Fixed Wing"}
local motorDirection = {"CW", "CCW"}
local becLvVoltage = {"6.0V", "7.4V","8.4V"}
local startupPower = {"Low", "Medium", "High"}
local fanControl = {"On", "Off"}
local ledColor = {"RED", "YELOW","ORANGE","GREEN","JADE GREEN","BLUE","CYAN","PURPLE","PINK","WHITE"}
local becHvVoltage = {"6.0V", "6.2V", "6.4V", "6.6V", "6.8V", "7.0V", "7.2V", "7.4V", "7.6V", "7.8V", "8.0V", "8.2V", "8.4V", "8.6V", "8.8V", "9.0V", "9.2V", "9.4V", "9.6V", "9.8V", "10.0V", "10.2V", "10.4V", "10.6V", "10.8V", "11.0V", "11.2V", "11.4V", "11.6V", "11.8V", "12.0V"}
local lowVoltage = {"OFF", "2.7V", "3.0V", "3.2V", "3.4V", "3.6V", "3.8V"}
local timing = {"Auto", "Low", "Medium", "High"}
local accel = {"Fast", "Normal", "Slow", "Very Slow"}
local brakeType = {"Normal", "Reverse"}
local autoRestart = {"OFF", "90s"}
local srFunc = {"ON", "OFF"}
local govMode = {"ESC Governor", "External Governor" , "Fixed Wing"}

-- api structure
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "esc_signature",       type = "U8",  apiVersion = 12.07, simResponse = {166}},
    {field = "esc_command",         type = "U8",  apiVersion = 12.07, simResponse = {0}},
    {field = "esc_model",           type = "U8",  apiVersion = 12.07, simResponse = {23}},
    {field = "esc_version",         type = "U8",  apiVersion = 12.07, simResponse = {3}},
    {field = "governor",            type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = govMode},
    {field = "cell_cutoff",         type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = lowVoltage},
    {field = "timing",              type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = timing},
    {field = "lv_bec_voltage",      type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = becLvVoltage},
    {field = "motor_direction",     type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = motorDirection},
    {field = "gov_p",               type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 1, max = 10, default = 4},
    {field = "gov_i",               type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 1, max = 10, default = 3},
    {field = "acceleration",        type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = accel},
    {field = "auto_restart_time",   type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = autoRestart},
    {field = "hv_bec_voltage",      type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = becHvVoltage},
    {field = "startup_power",       type = "U16", apiVersion = 12.07, simResponse = {0, 0}, table = startupPower, tableIdxInc = -1},
    {field = "brake_type",          type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = brakeType},
    {field = "brake_force",         type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 100, default = 0, unit = "%"},
    {field = "sr_function",         type = "U16", apiVersion = 12.07, simResponse = {0, 0}, table = srFunc, tableIdxInc = -1},
    {field = "capacity_correction", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 20, default = 10, offset = -10, unit = "%"},
    {field = "motor_poles",         type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 1, max = 55, default = 1, step = 1},
    {field = "led_color",           type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = ledColor},
    {field = "smart_fan",           type = "U16", apiVersion = 12.07, simResponse = {0, 0}, tableIdxInc = -1, table = fanControl},
    {field = "activefields",        type = "U32", apiVersion = 12.07, simResponse = {238, 255, 1, 0}},
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