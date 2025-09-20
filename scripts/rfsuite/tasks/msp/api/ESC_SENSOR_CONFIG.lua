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
local API_NAME = "ESC_SENSOR_CONFIG" -- API name (must be same as filename)
local MSP_API_CMD_READ = 123-- Command identifier for MSP Mixer Config Read
local MSP_API_CMD_WRITE = 216 -- Command identifier for saving Mixer Config Settings
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 

-- Define the MSP response data structures

-- note. This api has currently only been tested for the last two entries
local escTypes = {"NONE","BLHELI32", "HOBBYWING V4", "HOBBYWING V5", "SCORPION", "KONTRONIK", "OMPHOBBY", "ZTW", "APD", "OPENYGE", "FLYROTOR", "GRAUPNER", "XDFLY","RECORD"}
local onOff = {"@i18n(api.ESC_SENSOR_CONFIG.tbl_off)@","@i18n(api.ESC_SENSOR_CONFIG.tbl_on)@"}
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "protocol",                                        type = "U8",  apiVersion = 12.06, simResponse = {0},     table = escTypes, tableIdxInc= -1, help ="@i18n(api.ESC_SENSOR_CONFIG.protocol)@"},
    {field = "half_duplex",                                     type = "U8",  apiVersion = 12.06, simResponse = {0},     default = 0, min= 1, max = 2, table = onOff, tableIdxInc = -1, help ="@i18n(api.ESC_SENSOR_CONFIG.half_duplex)@"},
    {field = "update_hz",                                       type = "U16", apiVersion = 12.06, simResponse = {200, 0}, default = 200, min = 10, max = 500, unit = "Hz", help ="@i18n(api.ESC_SENSOR_CONFIG.update_hz)@"},
    {field = "current_offset",                                  type = "U16", apiVersion = 12.06, simResponse = {0, 15}, min = 0, max = 1000, default = 0, help ="@i18n(api.ESC_SENSOR_CONFIG.current_offset)@"},
    {field = "hw4_current_offset",                              type = "U16", apiVersion = 12.06, simResponse = {0, 0},  min = 0, max = 1000, default = 0, help ="@i18n(api.ESC_SENSOR_CONFIG.hw4_current_offset)@"},
    {field = "hw4_current_gain",                                type = "U8",  apiVersion = 12.06, simResponse = {0},     min = 0, max = 250, default = 0, help ="@i18n(api.ESC_SENSOR_CONFIG.hw4_current_gain)@"},
    {field = "hw4_voltage_gain",                                type = "U8",  apiVersion = 12.06, simResponse = {30},    min = 0, max = 250,  default = 30, help ="@i18n(api.ESC_SENSOR_CONFIG.hw4_voltage_gain)@"},
    {field = "pin_swap",                                        type = "U8",  apiVersion = 12.07, simResponse = {0},     table = onOff, tableIdxInc = -1, help ="@i18n(api.ESC_SENSOR_CONFIG.pin_swap)@"},
    {field = "voltage_correction",           mandatory = false, type = "S8",  apiVersion = 12.08, simResponse = {0},     unit = "%", default = 1, min = -99, max = 125, help ="@i18n(api.ESC_SENSOR_CONFIG.voltage_correction)@"},
    {field = "current_correction",           mandatory = false, type = "S8",  apiVersion = 12.08, simResponse = {0},     unit = "%", default = 1, min = -99, max = 125, help ="@i18n(api.ESC_SENSOR_CONFIG.current_correction)@"},
    {field = "consumption_correction",       mandatory = false, type = "S8",  apiVersion = 12.08, simResponse = {0},     unit = "%", default = 1, min = -99, max = 125, help ="@i18n(api.ESC_SENSOR_CONFIG.consumption_correction)@"},
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
