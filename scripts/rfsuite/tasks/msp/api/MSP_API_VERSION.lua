--[[

 * Copyright (C) Rotorflight Project
 *
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
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --

--[[  
-- USAGE GUIDE
local apiVersion = require("MSP_API_VERSION")

-- Initialize module and fetch data
apiVersion:init()

-- Wait for data and retrieve values
local versionMajor = apiVersion:getData("API_VERSION_MAJOR")
local versionMinor = apiVersion:getData("API_VERSION_MINOR")
print("Current API Version: " .. tostring(versionMajor) .. "." .. tostring(versionMinor))

-- Update values and write back (if allowed)
apiVersion:setParam("API_VERSION_MAJOR", 2)
apiVersion:setParam("API_VERSION_MINOR", 1)
apiVersion:writeData()

-- Get formatted version
local formattedVersion = apiVersion:getVersion()
print("Formatted Version: " .. tostring(formattedVersion))
]]


local READ_ID = 1        -- The id on the FBL used for read commands
local WRITE_ID = nil     -- The id on the FBL used for write commands (nil prevents)

local MSP_API_VERSION = {}

-- Internal buffers to hold read and write data
MSP_API_VERSION.readData = {}
MSP_API_VERSION.writeDataBuffer = {}

-- Define the read data structure (order and sizes)
MSP_API_VERSION.readStructure = {
    { key = "MSP_PROTOCOL_VERSION", bits = 8 },
    { key = "API_VERSION_MAJOR", bits = 8 },
    { key = "API_VERSION_MINOR", bits = 8 }
}

-- Define the write data structure (order and sizes)
MSP_API_VERSION.writeStructure = {
    { key = "MSP_PROTOCOL_VERSION", bits = 8 },
    { key = "API_VERSION_MAJOR", bits = 8 },
    { key = "API_VERSION_MINOR", bits = 8 }
}

-- Define the simulator response we expect
local simulatorResponse = rfsuite.config.simulatorApiVersionResponse or {0, 12, 07}

-- Count the elements for read and write
local readStructureCount = #MSP_API_VERSION.readStructure
local writeStructureCount = #MSP_API_VERSION.writeStructure

-- same statefull stuff
local writeCompleteState = false
local readCompleteState = false

-- Initialise the api by fetching data
function MSP_API_VERSION:init()
    if READ_ID ~= nil then
        self:fetchData()
    end    
end

-- Custom function to return the version as a single floating-point value
function MSP_API_VERSION:getVersion()
    local major = self:getData("API_VERSION_MAJOR")
    local minor = self:getData("API_VERSION_MINOR")

    if not major or not minor then
        rfsuite.utils.log("Version data is not available or incomplete.")
        return nil
    end

    -- Prevent division by zero or invalid operations
    if minor == 0 then
        return major  -- No minor version, just return major
    end

    -- Ensure minor is not nil or zero before calculating digits
    local minorDigits = 1
    if minor > 0 then
        minorDigits = math.floor(math.log(minor) / math.log(10)) + 1
    end

    local version = major + minor / (10 ^ minorDigits)
    return version
end

--  check to see if we have completed a read
function MSP_API_VERSION:readComplete()
    return readCompleteState
end    

-- check to see if we have completed a write
function MSP_API_VERSION:writeComplete()
    return writeCompleteState
end  

-- check to see if we have completed a write
function MSP_API_VERSION:flushLocks()
    writeCompleteState = false
    readCompleteState = false
end  

-- The functions below simple map to function in api.lua. This is done because
-- the same code is used in 99% of the api calls and as such sharing the code 
-- make sense. 

-- Parse raw MSP response buffer into structured readData table
function MSP_API_VERSION:parseResponse(buf)
    rfsuite.bg.msp.api.parseResponse(buf, self.readStructure, self.readData)
end

-- Build byte stream for sending based on write data table
function MSP_API_VERSION:buildWriteRequest()
    return rfsuite.bg.msp.api.buildWriteRequest(self.writeStructure, self.writeDataBuffer)
end

-- Get data by key or full read data (offloaded to api.lua to avoid duplication)
function MSP_API_VERSION:getData(key)
    return rfsuite.bg.msp.api.getData(self.readData, key)
end

-- Set value and prepare for write
function MSP_API_VERSION:setParam(key, value)
    rfsuite.bg.msp.api.setParam(self.writeDataBuffer, self.writeStructure, key, value)
end

-- Write updated data back using write structure (offloaded to api.lua to avoid duplication)
function MSP_API_VERSION:writeData()
    rfsuite.bg.msp.api.writeData(WRITE_ID, rfsuite.bg.msp.api.buildWriteRequest, self.writeStructure, self.writeDataBuffer, function() writeCompleteState = true end, nil)
end

-- Fetch data from MSP
function MSP_API_VERSION:fetchData()
    rfsuite.bg.msp.api.fetchData(READ_ID, rfsuite.bg.msp.api.parseResponse, self.readStructure, #self.readStructure, self.readData, function() readCompleteState = true end, nil, simulatorResponse)
end


return MSP_API_VERSION
