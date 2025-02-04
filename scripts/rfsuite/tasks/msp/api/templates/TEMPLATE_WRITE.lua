--[[
 *********************************************************************************************
 *                                                                                           *
 *     THIS IS A TEMPLATE AND SHOULD BE USED ONLY AS A SOURCE FOR MAKING A NEW API FILE      *
 *                                                                                           *
 *********************************************************************************************
]] --

--[[
 * Rotorflight API Template - Write Operations
 * -------------------------------------------
 * This API provides a template for handling MSP (MultiWii Serial Protocol) write commands.
 * It allows sending PID tuning parameters to the flight controller and monitoring the write status.
 * 
 * Functions:
 * - write(suppliedPayload): Initiates an MSP command to set the RTC with optional payload.
 * - setValue(fieldName, value): Sets an individual value dynamically in the payload.
 * - writeComplete(): Checks if the write operation is complete.
 * - resetWriteStatus(): Resets the write completion status.
 * - getDefaults(): Retrieves default values stored for MSP writes.
 * - setDefaults(data): Sets default values for the MSP write operation.
 * - setCompleteHandler(handlerFunction): Assigns a function to execute on write completion.
 * - setErrorHandler(handlerFunction): Assigns a function to execute if an error occurs.
 *
 * MSP Command Used:
 * - MSP_SET_PID_TUNING (Command ID: 202)
 *
 * Usage:
 * - Modify this template for new API files by implementing appropriate MSP commands and handlers.
 * - Ensure you update relevant documentation when making changes.
]] --

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

-- Define the MSP request data structure based on PID and cyclic axis counts
local MSP_STRUCTURE = generate_pid_structure(3, 2)

-- Variable to track write completion status
local mspWriteComplete = false

-- Tables for handling payload data
local payloadData = {}
local defaultData = {}

-- Create a new instance of handlers for processing MSP commands
local handlers = rfsuite.bg.msp.api.createHandlers()

--[[
 * Function: getDefaults
 * ----------------------
 * Retrieves the default values for the MSP write operation.
 *
 * Returns:
 * - table: Default values used when no payload is explicitly provided.
]]--
local function getDefaults()
    if defaultData['parsed'] then
        return defaultData['parsed']
    else    
        return defaultData
    end
end

--[[
 * Function: setDefaults
 * ----------------------
 * Sets default values for the write operation to avoid unnecessary MSP calls.
 *
 * Parameters:
 * - data (table): The default data to use when constructing the payload.
]]--
local function setDefaults(data)
    defaultData = data 
end

--[[
 * Function: write
 * ---------------
 * Initiates an MSP write operation to send PID tuning data.
 *
 * Parameters:
 * - suppliedPayload (optional, table): A payload table containing PID values.
 *
 * If no payload is provided, the function constructs one using default values.
 * Ensures that all required fields are populated before sending the command.
]]--
local function write(suppliedPayload)
    if suppliedPayload then
        local message = {
            command = MSP_API_CMD,
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
        rfsuite.bg.msp.mspQueue:add(message)
    else
        local defaults = getDefaults()
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
    end
end

--[[
 * Function: setValue
 * ------------------
 * Dynamically sets a value for a specific PID field.
 *
 * Parameters:
 * - fieldName (string): The name of the PID field to update.
 * - value (number): The value to assign.
 *
 * Returns:
 * - boolean: True if the value was successfully set.
]]--
local function setValue(fieldName, value)
    for _, field in ipairs(MSP_STRUCTURE) do
        if field.field == fieldName then
            payloadData[fieldName] = value
            return true
        end
    end
    error("Invalid field name: " .. fieldName)
end

--[[
 * Function: writeComplete
 * -----------------------
 * Checks if the write operation has completed.
 *
 * Returns:
 * - boolean: True if the write operation is complete, otherwise false.
]]--
local function writeComplete()
    return mspWriteComplete
end

--[[
 * Function: resetWriteStatus
 * --------------------------
 * Resets the write completion status flag.
]]--
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
    setDefaults = setDefaults,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler
}
