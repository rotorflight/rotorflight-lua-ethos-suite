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
local API_NAME = "RTC" -- API name (must be same as filename)
local MSP_API_CMD_WRITE = 246 -- Command identifier for setting RTC

-- Define the MSP request data structure
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local MSP_STRUCTURE_WRITE = {{field = "seconds", type = "U32"}, -- 32-bit seconds since epoch
{field = "milliseconds", type = "U16"} -- 16-bit milliseconds
}

-- Variable to track write completion
local mspWriteComplete = false

-- Function to create a payload table
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.tasks.msp.api.createHandlers()

-- Variables to store optional the UUID and timeout for payload
local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

-- Function to get default values (stub for now)
local function getDefaults()
    -- This function should return a table with default values
    -- Typically we should be performing a 'read' to populate this data
    -- however this api only ever writes data
    return {seconds = os.time(), milliseconds = 0}
end

-- Function to initiate MSP write operation
local function write()
    local defaults = getDefaults()
    -- Validate if all fields have been set or fallback to defaults
    for _, field in ipairs(MSP_STRUCTURE_WRITE) do
        if payloadData[field.field] == nil then
            if defaults[field.field] ~= nil then
                payloadData[field.field] = defaults[field.field]
            else
                error("Missing value for field: " .. field.field)
                return
            end
        end
    end

    local message = {
        command = MSP_API_CMD_WRITE, -- Specify the MSP command
        payload = {},
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

    -- Fill payload with data from payloadData table
    for _, field in ipairs(MSP_STRUCTURE_WRITE) do

        local byteorder = field.byteorder or "little" -- Default to little-endian

        if field.type == "U32" then
            rfsuite.tasks.msp.mspHelper.writeU32(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "S32" then
            rfsuite.tasks.msp.mspHelper.writeU32(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "U24" then
            rfsuite.tasks.msp.mspHelper.writeU24(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "S24" then
            rfsuite.tasks.msp.mspHelper.writeU24(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "U16" then
            rfsuite.tasks.msp.mspHelper.writeU16(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "S16" then
            rfsuite.tasks.msp.mspHelper.writeU16(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "U8" then
            rfsuite.tasks.msp.mspHelper.writeU8(message.payload, payloadData[field.field])
        elseif field.type == "S8" then
            rfsuite.tasks.msp.mspHelper.writeU8(message.payload, payloadData[field.field])
        end
    end

    -- Add the message to the processing queue
    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    for _, field in ipairs(MSP_STRUCTURE_WRITE) do
        if field.field == fieldName then
            payloadData[fieldName] = value
            return true
        end
    end
    error("Invalid field name: " .. fieldName)
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
    write = write,
    setValue = setValue,
    writeComplete = writeComplete,
    resetWriteStatus = resetWriteStatus,
    getDefaults = getDefaults,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}