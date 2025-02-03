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
 * - resetWriteStatus(): Resets the write completion status.
 * - setCompleteHandler(handlerFunction):  Set function to run on completion
 * - setErrorHandler(handlerFunction): Set function to run on error  
 *
 * MSP Command Used:
 * - MSP_SET_RTC (Command ID: 202)
]] --
-- Constants for MSP Commands
local MSP_API_CMD = 202 -- Command identifier for saving PID settings

-- function to help generate the pid structure
-- if you update this - also update the same function in the read api
local function generate_pid_structure(pid_axis_count, cyclic_axis_count)
    local structure = {}

    for i = 0, pid_axis_count - 1 do
        table.insert(structure, { field = "pid_" .. i .. "_P", type = "U16" })
        table.insert(structure, { field = "pid_" .. i .. "_I", type = "U16" })
        table.insert(structure, { field = "pid_" .. i .. "_D", type = "U16" })
        table.insert(structure, { field = "pid_" .. i .. "_F", type = "U16" })
    end

    for i = 0, pid_axis_count - 1 do
        table.insert(structure, { field = "pid_" .. i .. "_B", type = "U16" })
    end

    for i = 0, cyclic_axis_count - 1 do
        table.insert(structure, { field = "pid_" .. i .. "_O", type = "U16" })
    end

    return structure
end

-- Define the MSP request data structure
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local MSP_STRUCTURE = generate_pid_structure(3, 2)

-- Variable to track write completion
local mspWriteComplete = false

-- Function to create a payload table
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()  

-- Function to get default values
local function getDefaults()

    local API = rfsuite.bg.msp.api.load("MSP_PID_TUNING")
    API.setCompleteHandler(function(self, buf)
        defaultData = API.data()
    end)
    API.read()

    return defaultData
end

-- Function to initiate MSP write operation
local function write(suppliedPayload)

    -- its possible to send the actual payload that will be written.
    -- this is mostly used within the app framework where we use app.Page.values
    -- keeping this up2date while changing form field values.
    -- under normal circumstances write would be called with no parameters; instead
    -- relying on the setValue function to build up a payload
    if suppliedPayload then

        local message = {
            command = MSP_API_CMD, -- Specify the MSP command
            payload = suppliedPayload,
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

        -- Add the message to the processing queue
        rfsuite.bg.msp.mspQueue:add(message)

    else
        -- NOTE. This api has not yet had the functionality tested around getDefaults below.

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
    setPayload = setPayload,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler
}
