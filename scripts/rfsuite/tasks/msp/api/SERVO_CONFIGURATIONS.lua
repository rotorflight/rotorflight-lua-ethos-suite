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
local MSP_API_CMD_READ = 120 -- Command identifier
local MSP_API_CMD_WRITE = nil -- Command identifier 
local MSP_API_SIMULATOR_RESPONSE = {4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0} -- Default simulator response
local MSP_MIN_BYTES = 1

local MSP_API_STRUCTURE_WRITE = nil -- We have to dynamicall generate for servos
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ -- Assuming identical structure for now

-- Variable to store parsed MSP data
local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()

-- Define the MSP response data structure (note that we have dynamic stuff below)
local function generateMSPStructureRead(servoCount)
    local MSP_API_STRUCTURE = {{field = "servo_count", type = "U8"} -- The servo count comes first
    }

    -- Define servo fields structure
    local servo_fields = {{field = "mid", type = "U16"}, {field = "min", type = "U16"}, {field = "max", type = "U16"}, {field = "rneg", type = "U16"}, {field = "rpos", type = "U16"}, {field = "rate", type = "U16"}, {field = "speed", type = "U16"}, {field = "flags", type = "U16"}}

    -- Add servo field structures dynamically based on servoCount
    for i = 1, servoCount do for _, field in ipairs(servo_fields) do table.insert(MSP_API_STRUCTURE, {field = string.format("servo_%d_%s", i, field.field), type = field.type}) end end

    return MSP_API_STRUCTURE
end

-- Custom process function to suite the servo data
local function processMSPData(buf, MSP_API_STRUCTURE_READ)
    local data = {
        servos = {} -- Create a nested table to hold servo data
    }

    -- Ensure buffer is valid
    if not buf or type(buf) ~= "table" then return nil end

    for i, field in ipairs(MSP_API_STRUCTURE_READ) do
        local baseName, servoIndex = field.field:match("servo_(%d+)_(.+)")
        local value = 0

        -- Determine data type and extract values from buffer
        if field.type == "U8" then
            value = buf[i] or 0
        elseif field.type == "U16" then
            value = (buf[i] or 0) + ((buf[i + 1] or 0) * 256)
        end

        if baseName and servoIndex then
            local keyIndex = tonumber(baseName) - 1 -- Convert to zero-based index

            if not data.servos[keyIndex] then data.servos[keyIndex] = {} end

            data.servos[keyIndex][servoIndex] = value
        else
            -- Handle top-level fields like "servo_count"
            data[field.field] = value
        end
    end

    return data
end

-- Function to initiate MSP read operation
local function read()
    local message = {
        command = MSP_API_CMD_READ, -- Specify the MSP command
        processReply = function(self, buf)
            -- Generate the MSP structure dynamically
            local servoCount = buf[1]
            MSP_MIN_BYTES = 1 + (servoCount * 16) -- Update MSP_MIN_BYTES dynamically

            local MSP_API_STRUCTURE_READ = generateMSPStructureRead(servoCount)
            mspData = rfsuite.bg.msp.api.parseMSPData(buf, MSP_API_STRUCTURE_READ, processMSPData(buf, MSP_API_STRUCTURE_READ))
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
    -- Add the message to the processing queue
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
