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
local MSP_API_CMD_READ = 152 -- Command identifier 
local MSP_API_CMD_WRITE = 153 -- Command identifier 
local MSP_API_SIMULATOR_RESPONSE = {1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232, 3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 1, 2, 24, 252, 232, 3, 1, 3, 24, 252, 232,
                                    3, 1, 0, 24, 252, 232, 3, 1, 1, 24, 252, 232, 3, 50} -- Default simulator response
local MSP_MIN_BYTES = 34

local function generateSbusApiStructure(numChannels)
    local structure = {}

    for i = 1, numChannels do
        table.insert(structure, {field = "Type_" .. i, type = "U8"})
        table.insert(structure, {field = "Index_" .. i, type = "U8"})
        table.insert(structure, {field = "RangeLow_" .. i, type = "S16"})
        table.insert(structure, {field = "RangeHigh_" .. i, type = "S16"})
    end

    return structure
end

-- Define the MSP response data structures
local MSP_API_STRUCTURE_READ = generateSbusApiStructure(16)
local MSP_API_STRUCTURE_WRITE = {{field = "target_channel", type = "U8"}, {field = "source_type", type = "U8"}, {field = "source_index", type = "U8"}, {field = "source_range_low", type = "S16"}, {field = "source_range_high", type = "S16"}}

-- Variable to store parsed MSP data
local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()

-- Function to initiate MSP read operation
local function read()
    if MSP_API_CMD_READ == nil then
        print("No value set for MSP_API_CMD_READ")
        return
    end

    local message = {
        command = MSP_API_CMD_READ,
        processReply = function(self, buf)
            mspData = rfsuite.bg.msp.api.parseMSPData(buf, MSP_API_STRUCTURE_READ)
            if #buf >= MSP_MIN_BYTES then
                local completeHandler = handlers.getCompleteHandler()
                if completeHandler then completeHandler(self, buf) end
            end
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        print("No value set for MSP_API_CMD_WRITE")
        return
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = suppliedPayload or payloadData,
        processReply = function(self, buf)
            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then completeHandler(self, buf) end
            mspWriteComplete = true
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = {}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    for _, field in ipairs(MSP_API_STRUCTURE_WRITE) do
        if field.field == fieldName then
            payloadData[fieldName] = value
            return true
        end
    end
    error("Invalid field name: " .. fieldName)
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

-- Return the module's API functions
return {read = read, write = write, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data}
