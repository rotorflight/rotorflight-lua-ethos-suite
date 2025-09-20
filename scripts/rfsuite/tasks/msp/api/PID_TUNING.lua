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
local API_NAME = "PID_TUNING" -- API name (must be same as filename)
local MSP_API_CMD_READ = 112 -- Command identifier 
local MSP_API_CMD_WRITE = 202 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 


-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "pid_0_P", type = "U16", apiVersion = 12.06, simResponse = {50, 0},  min = 0, max = 1000, default = 50, help = "@i18n(api.PID_TUNING.pid_0_P)@"},
    {field = "pid_0_I", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 1000, default = 100, help = "@i18n(api.PID_TUNING.pid_0_I)@"},
    {field = "pid_0_D", type = "U16", apiVersion = 12.06, simResponse = {20, 0},  min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_0_D)@"},
    {field = "pid_0_F", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 1000, default = 100, help = "@i18n(api.PID_TUNING.pid_0_F)@"},
    
    {field = "pid_1_P", type = "U16", apiVersion = 12.06, simResponse = {50, 0},  min = 0, max = 1000, default = 50, help = "@i18n(api.PID_TUNING.pid_1_P)@"},
    {field = "pid_1_I", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 1000, default = 100, help = "@i18n(api.PID_TUNING.pid_1_I)@"},
    {field = "pid_1_D", type = "U16", apiVersion = 12.06, simResponse = {50, 0},  min = 0, max = 1000, default = 40, help = "@i18n(api.PID_TUNING.pid_1_D)@"},
    {field = "pid_1_F", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 1000, default = 100, help = "@i18n(api.PID_TUNING.pid_1_F)@"},
  
    {field = "pid_2_P", type = "U16", apiVersion = 12.06, simResponse = {80, 0},  min = 0, max = 1000, default = 80, help = "@i18n(api.PID_TUNING.pid_2_P)@"},
    {field = "pid_2_I", type = "U16", apiVersion = 12.06, simResponse = {120, 0}, min = 0, max = 1000, default = 120, help = "@i18n(api.PID_TUNING.pid_2_I)@"},
    {field = "pid_2_D", type = "U16", apiVersion = 12.06, simResponse = {40, 0},  min = 0, max = 1000, default = 10, help = "@i18n(api.PID_TUNING.pid_2_D)@"},
    {field = "pid_2_F", type = "U16", apiVersion = 12.06, simResponse = {0, 0},   min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_2_F)@"},
  
    {field = "pid_0_B", type = "U16", apiVersion = 12.06, simResponse = {0, 0},   min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_0_B)@"},
    {field = "pid_1_B", type = "U16", apiVersion = 12.06, simResponse = {0, 0},   min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_1_B)@"},
    {field = "pid_2_B", type = "U16", apiVersion = 12.06, simResponse = {0, 0},   min = 0, max = 1000, default = 0}, help = "@i18n(api.PID_TUNING.pid_2_B)@",
 
    {field = "pid_0_O", type = "U16", apiVersion = 12.06, simResponse = {45, 0},  min = 0, max = 1000, default = 45, help = "@i18n(api.PID_TUNING.pid_0_O)@"},
    {field = "pid_1_O", type = "U16", apiVersion = 12.06, simResponse = {45, 0},  min = 0, max = 1000, default = 45, help = "@i18n(api.PID_TUNING.pid_1_O)@"},
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
