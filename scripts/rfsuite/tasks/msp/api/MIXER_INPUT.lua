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
local API_NAME = "MIXER_INPUT" -- API name (must be same as filename)
local MSP_API_CMD_READ = 170 -- Command identifier 
local MSP_API_CMD_WRITE = 171 -- Command identifier 
local MSP_REBUILD_ON_WRITE = true -- Rebuild the payload on write 


-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rate_0", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, help = "@i18n(api.MIXER_INPUT.rate_0)@"}, -- Rate for input 0
    {field = "min_0",  type = "U16", apiVersion = 12.06, simResponse = {0, 0}, help = "@i18n(api.MIXER_INPUT.min_0)@"},  -- Minimum for input 0
    {field = "max_0",  type = "U16", apiVersion = 12.06, simResponse = {0, 0}, help = "@i18n(api.MIXER_INPUT.max_0)@"},  -- Maximum for input 0

    {field = "rate_1", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_1)@"},
    {field = "min_1",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_1)@"},
    {field = "max_1",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_1)@"},

    {field = "rate_2", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_2)@"},
    {field = "min_2",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_2)@"},
    {field = "max_2",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_2)@"},

    {field = "rate_3", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_3)@"},
    {field = "min_3",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_3)@"},
    {field = "max_3",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_3)@"},

    {field = "rate_4", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_4)@"},
    {field = "min_4",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_4)@"},
    {field = "max_4",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_4)@"},

    {field = "rate_5", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_5)@"},
    {field = "min_5",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_5)@"},
    {field = "max_5",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_5)@"},

    {field = "rate_6", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_6)@"},
    {field = "min_6",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_6)@"},
    {field = "max_6",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_6)@"},

    {field = "rate_7", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_7)@"},
    {field = "min_7",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_7)@"},
    {field = "max_7",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_7)@"},

    {field = "rate_8", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_8)@"},
    {field = "min_8",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_8)@"},
    {field = "max_8",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_8)@"},

    {field = "rate_9", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_9)@"},
    {field = "min_9",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_9)@"},
    {field = "max_9",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_9)@"},

    {field = "rate_10", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_10)@"},
    {field = "min_10",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_10)@"},
    {field = "max_10",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_10)@"},

    {field = "rate_11", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_11)@"},
    {field = "min_11",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_11)@"},
    {field = "max_11",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_11)@"},

    {field = "rate_12", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_12)@"},
    {field = "min_12",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_12)@"},
    {field = "max_12",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_12)@"},

    {field = "rate_13", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_13)@"},
    {field = "min_13",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_13)@"},
    {field = "max_13",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_13)@"},

    {field = "rate_14", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_14)@"},
    {field = "min_14",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_14)@"},
    {field = "max_14",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_14)@"},

    {field = "rate_15", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_15)@"},
    {field = "min_15",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_15)@"},
    {field = "max_15",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_15)@"},

    {field = "rate_16", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_16)@"},
    {field = "min_16",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_16)@"},
    {field = "max_16",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_16)@"},

    {field = "rate_17", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_17)@"},
    {field = "min_17",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_17)@"},
    {field = "max_17",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_17)@"},

    {field = "rate_18", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_18)@"},
    {field = "min_18",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_18)@"},
    {field = "max_18",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_18)@"},

    {field = "rate_19", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_19)@"},
    {field = "min_19",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_19)@"},
    {field = "max_19",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_19)@"},

    {field = "rate_20", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_20)@"},
    {field = "min_20",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_20)@"},
    {field = "max_20",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_20)@"},

    {field = "rate_21", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_21)@"},
    {field = "min_21",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_21)@"},
    {field = "max_21",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_21)@"},

    {field = "rate_22", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_22)@"},
    {field = "min_22",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_22)@"},
    {field = "max_22",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_22)@"},

    {field = "rate_23", type = "U16", apiVersion = 12.06, simResponse = {251, 0}, help = "@i18n(api.MIXER_INPUT.rate_23)@"},
    {field = "min_23",  type = "U16", apiVersion = 12.06, simResponse = {30, 251}, help = "@i18n(api.MIXER_INPUT.min_23)@"},
    {field = "max_23",  type = "U16", apiVersion = 12.06, simResponse = {226, 4}, help = "@i18n(api.MIXER_INPUT.max_23)@"},
}


-- Process structure in one pass
local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE =
    rfsuite.tasks.msp.api.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- set read structure
local MSP_API_STRUCTURE_WRITE = {
        {field = "index",         type = "U8", apiVersion = 12.06},
        {field = "rate",          type = "U16",  apiVersion = 12.06},
        {field = "min",           type = "U16",  apiVersion = 12.06},
        {field = "max",           type = "U16",  apiVersion = 12.06},
}


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
