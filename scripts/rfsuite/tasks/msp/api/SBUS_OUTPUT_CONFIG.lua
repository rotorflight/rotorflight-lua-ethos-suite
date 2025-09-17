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
local API_NAME = "SBUS_OUTPUT_CONFIG" -- API name (must be same as filename)
local MSP_API_CMD_READ = 152 -- Command identifier 
local MSP_API_CMD_WRITE = 153 -- Command identifier 
local MSP_REBUILD_ON_WRITE = true -- Rebuild the payload on write 

local function generateSbusApiStructure(numChannels)
    local structure = {}

    for i = 1, numChannels do
        table.insert(structure, {field = "Type_" .. i, type = "U8", min=0, max = 16,      apiVersion = 12.06, simResponse = {1}, help = "@i18n(api.msp.sbus_output_config.type)@"})
        table.insert(structure, {field = "Index_" .. i, type = "U8", min=0, max = 15,     apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.msp.sbus_output_config.index)@"})
        table.insert(structure, {field = "RangeLow_" .. i, type = "S16", min = -2000, max = 2000, apiVersion = 12.06, simResponse = {24, 252}, help = "@i18n(api.msp.sbus_output_config.range_low)@"})
        table.insert(structure, {field = "RangeHigh_" .. i, type = "S16", min = -2000, max = 2000, apiVersion = 12.06, simResponse = {232, 3}, help = "@i18n(api.msp.sbus_output_config.range_high)@"})
    end

    return structure
end

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ_DATA = generateSbusApiStructure(16)

local MSP_API_STRUCTURE_WRITE = {
    {field = "target_channel",    type = "U8",  apiVersion = 12.06},
    {field = "source_type",       type = "U8",  apiVersion = 12.06},
    {field = "source_index",      type = "U8",  apiVersion = 12.06},
    {field = "source_range_low",  type = "S16", apiVersion = 12.06},
    {field = "source_range_high", type = "S16", apiVersion = 12.06}
}

-- filter the structure to remove any params not supported by the running api version
local MSP_API_STRUCTURE_READ = rfsuite.tasks.msp.api.filterByApiVersion(MSP_API_STRUCTURE_READ_DATA)

-- calculate the min bytes value from the structure
local MSP_MIN_BYTES = rfsuite.tasks.msp.api.calculateMinBytes(MSP_API_STRUCTURE_READ)

-- generate a simulatorResponse from the read structure
local MSP_API_SIMULATOR_RESPONSE = rfsuite.tasks.msp.api.buildSimResponse(MSP_API_STRUCTURE_READ)

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
        
            rfsuite.tasks.msp.api.parseMSPData(buf, structure, nil, nil, {
                chunked = true,
                completionCallback = function(result)
                    mspData = result
                    if #buf >= MSP_MIN_BYTES then
                        local completeHandler = handlers.getCompleteHandler()
                        if completeHandler then completeHandler(self, buf) end
                    end
                end
            })
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
