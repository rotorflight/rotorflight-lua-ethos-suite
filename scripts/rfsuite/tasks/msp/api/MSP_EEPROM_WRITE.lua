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
--[[
 * MSP_SET_RTC Write API
 * --------------------
 * This module provides functions to set the real-time clock (RTC) using the MSP protocol.
 * The write function sends the current system time to the device, formatted as seconds since the epoch.
 *
 * Functions:
 * - write(): Initiates an MSP command to set the RTC.
 * - writeComplete(): Checks if the write operation is complete.
 * - setValue("seconds", os.time())
 * - setValue("milliseconds", 123)
 * - resetWriteStatus(): Resets the write completion status.
 * - setCompleteHandler(handlerFunction):  Set function to run on completion
 * - setErrorHandler(handlerFunction): Set function to run on error  
 *
 * MSP Command Used:
 * - MSP_EEPROM_WRITE (Command ID: 246)
]] --
-- Constants for MSP Commands
local MSP_API_CMD = 68 -- Command identifier for writing epprom

-- Define the MSP request data structure
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local MSP_STRUCTURE = {}

-- Variable to track write completion
local mspWriteComplete = false

-- Function to create a payload table
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()  

-- Function to get default values (stub for now)
local function getDefaults()
    -- This function should return a table with default values
    -- Typically we should be performing a 'read' to populate this data
    -- however this api only ever writes data
    return {}
end

-- Function to initiate MSP write operation
local function write()
    local defaults = getDefaults()
    -- Validate if all fields have been set or fallback to defaults
    for _, field in ipairs(MSP_STRUCTURE) do
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
        command = MSP_API_CMD, -- Specify the MSP command
        payload = {},
        processReply = function(self, buf)
            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then
                completeHandler(self, buf)
            end            
            mspWriteComplete = true
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then 
                errorHandler(self, buf)
            end
        end,
        simulatorResponse = {}
    }

    -- Fill payload with data from payloadData table
    for _, field in ipairs(MSP_STRUCTURE) do

        local byteorder = field.byteorder or "little" -- Default to little-endian

        if field.type == "U32" then
            rfsuite.bg.msp.mspHelper.writeU32(message.payload,
                                              payloadData[field.field],
                                              byteorder)
        elseif field.type == "S32" then
            rfsuite.bg.msp.mspHelper.writeU32(message.payload,
                                              payloadData[field.field],
                                              byteorder)
        elseif field.type == "U24" then
            rfsuite.bg.msp.mspHelper.writeU24(message.payload,
                                              payloadData[field.field],
                                              byteorder)
        elseif field.type == "S24" then
            rfsuite.bg.msp.mspHelper.writeU24(message.payload,
                                              payloadData[field.field],
                                              byteorder)
        elseif field.type == "U16" then
            rfsuite.bg.msp.mspHelper.writeU16(message.payload,
                                              payloadData[field.field],
                                              byteorder)
        elseif field.type == "S16" then
            rfsuite.bg.msp.mspHelper.writeU16(message.payload,
                                              payloadData[field.field],
                                              byteorder)
        elseif field.type == "U8" then
            rfsuite.bg.msp.mspHelper.writeU8(message.payload,
                                             payloadData[field.field])
        elseif field.type == "S8" then
            rfsuite.bg.msp.mspHelper.writeU8(message.payload,
                                             payloadData[field.field])
        end
    end

    -- Add the message to the processing queue
    rfsuite.bg.msp.mspQueue:add(message)
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    for _, field in ipairs(MSP_STRUCTURE) do
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

-- Return the module's API functions
return {
    write = write,
    setValue = setValue,
    writeComplete = writeComplete,
    resetWriteStatus = resetWriteStatus,
    getDefaults = getDefaults,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler
}
