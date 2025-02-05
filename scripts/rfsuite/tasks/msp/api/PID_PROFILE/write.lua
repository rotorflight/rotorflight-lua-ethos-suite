
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
local MSP_API_CMD = 95 -- Command identifier for saving PID profile settings

-- Define the MSP request data structure
--  field (name)
--  type (U8|U16|S16|etc) (see api.lua)
--  byteorder (big|little)
local apiPath = _G.paramMspApiPath -- passed as tmp global as called via dofile()
local structure = assert(loadfile(apiPath .. "/structure.lua"))()
local MSP_API_STRUCTURE = structure.MSP_API_STRUCTURE

-- Variable to track write completion
local mspWriteComplete = false

-- Function to create a payload table
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.bg.msp.api.createHandlers()  

-- Function to get default values
local function getDefaults()
    if defaultData['parsed'] then
        return defaultData['parsed']
    else    
        return defaultData
    end
end

-- Function to set defaults
local function setDefaults(data)
    defaultData = data -- Store data to prevent unnecessary MSP calls
end

-- Function to initiate MSP write operation
local function write(suppliedPayload)

    --[[
    * its possible to send the actual payload that will be written.
    * this is mostly used within the app framework where we use app.Page.values
    * keeping this up2date while changing form field values.
    * under normal circumstances write would be called with no parameters; instead
    * relying on the setValue function to build up a payload
    ]]--
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
    --[[
    * If no payload has been set; we are relying on a payload contructed
    * by using the setValue("key",value) functions.
    * the first part of this code retrieves the initial dataset that you
    * are expected to supply from an earlier read call - or manually
    * constructed table.  This is essential because even if you only want
    * to update one value; the msp call needs to send the entire dataset.
    *
    * the defaults are expected to be a table in the same format as supplied
    * by the MSP_API_STRUCTURE definition.  Its essentially a simple table of 
    * key=>value pairs.
    *           ['pid_2_I'] = 125,
    *            ['pid_2_B'] = 0,
    *            ['pid_2_P'] = 100,
    * etc...
    * 
    ]]--

        local defaults = getDefaults()

        -- Validate if all fields have been set or fallback to defaults
        for _, field in ipairs(MSP_API_STRUCTURE) do
            if payloadData[field.field] == nil then
                if defaults[field.field] ~= nil then
                    payloadData[field.field] = defaults[field.field]
                else
                    error("Missing value for field: " .. field.field .. "Check you have run setDefaults(<value from API:data() read api)")
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
        for _, field in ipairs(MSP_API_STRUCTURE) do

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

        if rfsuite.config.mspTxRxDebug or rfsuite.config.logEnable then
            local logData = "Saving: {" .. rfsuite.utils.joinTableItems(message.payload, ", ") .. "}"
            rfsuite.utils.log(logData)
            if rfsuite.config.mspTxRxDebug then print(logData) end
        end

        -- Add the message to the processing queue
        rfsuite.bg.msp.mspQueue:add(message)
    end
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    for _, field in ipairs(MSP_API_STRUCTURE) do
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
    setDefaults = setDefaults,
    setPayload = setPayload,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler
}
