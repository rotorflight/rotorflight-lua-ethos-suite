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
local READ_ID = 1        -- The id on the FBL used for read commands
local WRITE_ID = nil     -- The id on the FBL used for write commands (nil prevents)

local MSP_API_VERSION = {}


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

-- Count the elements for read and write
local readStructureCount = #MSP_API_VERSION.readStructure
local writeStructureCount = #MSP_API_VERSION.writeStructure

-- Internal buffers to hold read and write data
MSP_API_VERSION.readData = {}
MSP_API_VERSION.writeDataBuffer = {}

function MSP_API_VERSION:init()
    self:fetchData()
end

-- Parse raw MSP response buffer into structured readData table
function MSP_API_VERSION:parseResponse(buf)

    local index = 1
    for _, entry in ipairs(self.readStructure) do
        local key, bits = entry.key, entry.bits
        if bits == 8 then
            self.readData[key] = buf[index]
            rfsuite.utils.log("Parsed " .. key .. ": " .. tostring(buf[index]))
            index = index + 1
        elseif bits == 16 then
            self.readData[key] = buf[index] + (buf[index + 1] * 256)
            rfsuite.utils.log("Parsed " .. key .. ": " .. tostring(self.readData[key]))
            index = index + 2
        else
            rfsuite.utils.log("Unsupported data size for key: " .. key)
        end
    end
end

-- Build byte stream for sending based on write data table
function MSP_API_VERSION:buildWriteRequest()
    local requestData = {}
    for key, bits in pairs(self.writeStructure) do
        local value = self.writeDataBuffer[key] or 0
        if bits == 8 then
            table.insert(requestData, value & 0xFF)
        elseif bits == 16 then
            table.insert(requestData, value & 0xFF)
            table.insert(requestData, (value >> 8) & 0xFF)
        else
            rfsuite.utils.log("Unsupported data size for key: " .. key)
        end
    end
    return requestData
end

-- Fetch data from MSP
function MSP_API_VERSION:fetchData()
    if READ_ID == nil then
        rfsuite.utils.log("Read operation is disabled. READ_ID is nil.")
        return
    end

    local message = {
        command = READ_ID, -- MSP_API_VERSION
        processReply = function(_, buf)
			-- we do this to ensure all data has arrived
			if #buf >= readStructureCount then  
            	self:parseResponse(buf)
			end
        end,
        simulatorResponse = rfsuite.config.simulatorApiVersionResponse or {0, 12, 07}
    }
    rfsuite.bg.msp.mspQueue:add(message)
end

-- Get data by key or full read data
function MSP_API_VERSION:getData(key)
    if key then
        return self.readData[key]
    end
    return self.readData
end

-- Set value and prepare for write
function MSP_API_VERSION:setParam(key, value)
    if self.writeStructure[key] then
        self.writeDataBuffer[key] = value
    else
        rfsuite.utils.log("Invalid parameter for writing: " .. key)
    end
end

-- Write updated data back using write structure
function MSP_API_VERSION:writeData()
    if WRITE_ID == nil then
        rfsuite.utils.log("Write operation is disabled. WRITE_ID is nil.")
        return
    end

    local message = {
        command = WRITE_ID, -- MSP write command
        data = self:buildWriteRequest()
    }
    rfsuite.bg.msp.mspQueue:add(message)
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

return MSP_API_VERSION
