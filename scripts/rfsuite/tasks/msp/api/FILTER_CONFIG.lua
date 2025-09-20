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
local API_NAME = "FILTER_CONFIG" -- API name (must be same as filename)
local MSP_API_CMD_READ = 92 -- Command identifier 
local MSP_API_CMD_WRITE = 93 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 

local gyroFilterType = {[0]="@i18n(api.FILTER_CONFIG.tbl_none)@", [1]="@i18n(api.FILTER_CONFIG.tbl_1st)@", [2]="@i18n(api.FILTER_CONFIG.tbl_2nd)@"}
local rpmPreset = {"@i18n(api.FILTER_CONFIG.tbl_custom)@","@i18n(api.FILTER_CONFIG.tbl_low)@", "@i18n(api.FILTER_CONFIG.tbl_medium)@", "@i18n(api.FILTER_CONFIG.tbl_high)@"}

local MSP_API_STRUCTURE_READ_DATA = {
    { field = "gyro_hardware_lpf",        type = "U8",  apiVersion = 12.07, simResponse = {0 }, help = "@i18n(api.FILTER_CONFIG.gyro_hardware_lpf)@"},          
    { field = "gyro_lpf1_type",           type = "U8",  apiVersion = 12.07, simResponse = {1 }, min = 0, max = #gyroFilterType, table = gyroFilterType, help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_type)@"},          
    { field = "gyro_lpf1_static_hz",      type = "U16", apiVersion = 12.07, simResponse = {100, 0}, min = 0, max = 4000, unit = "Hz", default = 100 , help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_static_hz)@"},     
    { field = "gyro_lpf2_type",           type = "U8",  apiVersion = 12.07, simResponse = {0 }, min = 0, max = #gyroFilterType, table = gyroFilterType, help = "@i18n(api.FILTER_CONFIG.gyro_lpf2_type)@"},          
    { field = "gyro_lpf2_static_hz",      type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz" , help = "@i18n(api.FILTER_CONFIG.gyro_lpf2_static_hz)@"},       
    { field = "gyro_soft_notch_hz_1",     type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz" , help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_hz_1)@"},       
    { field = "gyro_soft_notch_cutoff_1", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz" , help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_cutoff_1)@"},       
    { field = "gyro_soft_notch_hz_2",     type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz" , help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_hz_2)@"},       
    { field = "gyro_soft_notch_cutoff_2", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz" , help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_cutoff_2)@"},       
    { field = "gyro_lpf1_dyn_min_hz",     type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 1000, unit = "Hz" , help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_dyn_min_hz)@"},       
    { field = "gyro_lpf1_dyn_max_hz",     type = "U16", apiVersion = 12.07, simResponse = {25, 0}, min = 0, max = 1000, unit = "Hz" , help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_dyn_max_hz)@"},     
    { field = "dyn_notch_count",          type = "U8",  apiVersion = 12.07, simResponse = {0 }, min = 0, max = 8, help = "@i18n(api.FILTER_CONFIG.dyn_notch_count)@"},          
    { field = "dyn_notch_q",              type = "U8",  apiVersion = 12.07, simResponse = {100}, min = 0, max = 100, decimals=1, scale = 10, help = "@i18n(api.FILTER_CONFIG.dyn_notch_q)@"},       
    { field = "dyn_notch_min_hz",         type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 10, max = 200, unit="Hz", help = "@i18n(api.FILTER_CONFIG.dyn_notch_min_hz)@"},       
    { field = "dyn_notch_max_hz",         type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 100, max = 500, unit="Hz", help = "@i18n(api.FILTER_CONFIG.dyn_notch_max_hz)@"},
    { field = "rpm_preset",               type = "U8",  apiVersion = 12.08, simResponse = {1 }, table = rpmPreset, tableIdxInc = -1, help = "@i18n(api.FILTER_CONFIG.rpm_preset)@"}, 
    { field = "rpm_min_hz",               type = "U8",  apiVersion = 12.08, simResponse = {20}, min = 1, max = 100, unit = "Hz" , help = "@i18n(api.FILTER_CONFIG.rpm_min_hz)@"},
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
