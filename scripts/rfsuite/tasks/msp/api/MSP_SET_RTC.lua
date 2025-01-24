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
local apiVersion = require("MSP_SET_RTC")

-- Initialize module and fetch data
apiVersion:init()

]]


local READ_ID = nil        -- The id on the FBL used for read commands
local WRITE_ID = 246     -- The id on the FBL used for write commands (nil prevents)

local MSP_SET_RTC = {}

-- Internal buffers to hold read and write data
MSP_SET_RTC.readData = {}
MSP_SET_RTC.writeDataBuffer = {}


-- Define the read data structure (order and sizes)
MSP_SET_RTC.readStructure = {
    { key = "SECONDS", bits = 32 },   -- 32-bit signed integer for epoch time
    { key = "MILLISECONDS", bits = 16 }  -- 16-bit unsigned integer for milliseconds
}

-- Define the write data structure (order and sizes)
MSP_SET_RTC.writeStructure = {
    { key = "SECONDS", bits = 32 },   -- 32-bit signed integer for epoch time
    { key = "MILLISECONDS", bits = 16 }  -- 16-bit unsigned integer for milliseconds
}

-- Define the simulator response we expect
local simulatorResponse = nil

-- same statefull stuff
local writeCompleteState = false
local readCompleteState = false

-- Count the elements for read and write
local readStructureCount = #MSP_SET_RTC.readStructure
local writeStructureCount = #MSP_SET_RTC.writeStructure

-- Initialise the api by fetching data
function MSP_SET_RTC:init()
    if READ_ID ~= nil then
        self:fetchData()
    end    
end

function MSP_SET_RTC:readComplete()
    return readCompleteState
end    

function MSP_SET_RTC:writeComplete()
    return writeCompleteState
end  

-- The functions below simple map to function in api.lua. This is done because
-- the same code is used in 99% of the api calls and as such sharing the code 
-- make sense. 

-- Parse raw MSP response buffer into structured readData table
function MSP_SET_RTC:parseResponse(buf)
    rfsuite.bg.msp.api.parseResponse(buf, self.readStructure, self.readData)
end

-- Build byte stream for sending based on write data table
function MSP_SET_RTC:buildWriteRequest()
    return rfsuite.bg.msp.api.buildWriteRequest(self.writeStructure, self.writeDataBuffer)
end

-- Get data by key or full read data (offloaded to api.lua to avoid duplication)
function MSP_SET_RTC:getData(key)
    return rfsuite.bg.msp.api.getData(self.readData, key)
end

-- Set value and prepare for write
function MSP_SET_RTC:setParam(key, value)
    rfsuite.bg.msp.api.setParam(self.writeDataBuffer, self.writeStructure, key, value)
end

-- Write updated data back using write structure (offloaded to api.lua to avoid duplication)
function MSP_SET_RTC:writeData()
    rfsuite.bg.msp.api.writeData(WRITE_ID, rfsuite.bg.msp.api.buildWriteRequest, self.writeStructure, self.writeDataBuffer, function() writeCompleteState = true end, nil)
end

-- Fetch data from MSP
function MSP_SET_RTC:fetchData()
    rfsuite.bg.msp.api.fetchData(READ_ID, rfsuite.bg.msp.api.parseResponse, self.readStructure, #self.readStructure, self.readData, function() readCompleteState = true end, nil, simulatorResponse)
end


return MSP_SET_RTC
