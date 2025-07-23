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
 * API Reference Guide
 * -------------------
 * read(): Initiates an MSP command to read data.
 * data(): Returns the parsed MSP data.
 * readComplete(): Checks if the read operation is complete.
 * readValue(fieldName): Returns the value of a specific field from MSP data.
 * readVersion(): Retrieves the API version in major.minor format.
 * setCompleteHandler(handlerFunction):  Set function to run on completion
 * setErrorHandler(handlerFunction): Set function to run on error  
]] --
-- Constants for MSP Commands
local API_NAME = "FC_VERSION" -- API name (must be same as filename)
local MSP_API_CMD_READ = 3 -- Command identifier for MSP API request
local MSP_API_SIMULATOR_RESPONSE = {4, 5, 1} -- Default simulator response

-- Define the MSP response data structure
local MSP_API_STRUCTURE_READ = {
    {field = "version_major", type = "U8"}, -- Major version
    {field = "version_minor", type = "U8"}, -- Minor version
    {field = "version_patch", type = "U8"}  -- Patch version
}

local MSP_MIN_BYTES = #MSP_API_STRUCTURE_READ -- Minimum bytes required for the structure

-- Variable to store parsed MSP data
local mspData = nil

-- Create a new instance
local handlers = rfsuite.tasks.msp.api.createHandlers()

-- Variables to store optional the UUID and timeout for payload
local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

-- Function to initiate MSP read operation
local function read()
    local message = {
        command = MSP_API_CMD_READ, -- Specify the MSP command
        processReply = function(self, buf)
            -- Parse the MSP data using the defined structure
            mspData = rfsuite.tasks.msp.api.parseMSPData(buf, MSP_API_STRUCTURE_READ)
            if #buf >= MSP_MIN_BYTES then
                local completeHandler = handlers.getCompleteHandler()
                if completeHandler then completeHandler(self, buf) end
            end
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT  
    }
    -- Add the message to the processing queue
    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Function to return the parsed MSP data
local function data()
    return mspData
end

-- Function to check if the read operation is complete
local function readComplete()
    if mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES then return true end
    return false
end

-- Function to get the API version in major.minor format
local function readVersion()
    if mspData then
        local parsed = mspData['parsed']
        return string.format("%d.%d.%d", parsed.version_major, parsed.version_minor, parsed.version_patch)
    end
    return nil
end


local function readRfVersion()

  local MAJOR_OFFSET = 2
  local MINOR_OFFSET = 3


  local raw = readVersion()
  if not raw then return nil end

  -- split into numbers
  local maj, min, patch = raw:match("(%d+)%.(%d+)%.(%d+)")
  maj = tonumber(maj) - MAJOR_OFFSET
  min = tonumber(min) - MINOR_OFFSET
  patch = tonumber(patch)

  -- guard against negatives or parse errors
  if maj < 0 or min < 0 then
    return raw
  end

  return string.format("%d.%d.%d", maj, min, patch)
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
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
    data = data,
    read = read,
    readComplete = readComplete,
    readVersion = readVersion,
    readRfVersion = readRfVersion,
    readValue = readValue,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    setUUID = setUUID,
    setTimeout = setTimeout
}
