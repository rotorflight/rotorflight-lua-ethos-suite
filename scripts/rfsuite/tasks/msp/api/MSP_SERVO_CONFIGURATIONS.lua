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
local apiVersion = require("MSP_MIXER_CONFIG")

-- Initialize module and fetch data
apiVersion:init()

-- Read some data
local mainRotorDir = apiVersion:getData("main_rotor_dir")

-- Update values and write back
apiVersion:setParam("swash_type", 3)
apiVersion:writeData()

]]


local READ_ID = 42        -- The id on the FBL used for read commands
local WRITE_ID = 43     -- The id on the FBL used for write commands (nil prevents)

local MSP_MIXER_CONFIG = {}

-- Internal buffers to hold read and write data
MSP_MIXER_CONFIG.readData = {}
MSP_MIXER_CONFIG.writeDataBuffer = {}

-- Define the read data structure (order and sizes)
MSP_MIXER_CONFIG.readStructure = {
    { key = "main_rotor_dir", bits = 8 },
    { key = "tail_rotor_mode", bits = 8 },
    { key = "tail_motor_idle", bits = 8 },
    { key = "tail_center_trim", bits = 16 },
    { key = "swash_type", bits = 8 },
    { key = "swash_ring", bits = 8 },
    { key = "swash_phase", bits = 16 },
    { key = "swash_pitch_limit", bits = 16 },
    { key = "swash_trim_0", bits = 16 },
    { key = "swash_trim_1", bits = 16 },
    { key = "swash_trim_2", bits = 16 },
    { key = "swash_tta_precomp", bits = 8 },
    { key = "swash_geo_correction", bits = 8 }
}

-- Define the write data structure (order and sizes)
MSP_MIXER_CONFIG.writeStructure = {

}

-- Define the simulator response we expect
local simulatorResponse = {4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0}

-- Count the elements for read and write
local readStructureCount = #MSP_MIXER_CONFIG.readStructure
local writeStructureCount = #MSP_MIXER_CONFIG.writeStructure

-- same statefull stuff
local writeCompleteState = false
local readCompleteState = false

-- Initialise the api by fetching data
function MSP_MIXER_CONFIG:init()
    if READ_ID ~= nil then
        self:fetchData()
    end    
end

--  check to see if we have completed a read
function MSP_MIXER_CONFIG:readComplete()
    return readCompleteState
end    

-- check to see if we have completed a write
function MSP_MIXER_CONFIG:writeComplete()
    return writeCompleteState
end  

-- check to see if we have completed a write
function MSP_MIXER_CONFIG:cleanState()
    writeCompleteState = false
    readCompleteState = false
end  

-- The functions below simple map to function in api.lua. This is done because
-- the same code is used in 99% of the api calls and as such sharing the code 
-- make sense. 

-- Parse raw MSP response buffer into structured readData table
function MSP_MIXER_CONFIG:parseResponse(buf)
    rfsuite.bg.msp.api.parseResponse(buf, self.readStructure, self.readData)
end

-- Build byte stream for sending based on write data table
function MSP_MIXER_CONFIG:buildWriteRequest()
    return rfsuite.bg.msp.api.buildWriteRequest(self.writeStructure, self.writeDataBuffer)
end

-- Get data by key or full read data (offloaded to api.lua to avoid duplication)
function MSP_MIXER_CONFIG:getData(key)
    return rfsuite.bg.msp.api.getData(self.readData, key)
end

-- Set value and prepare for write
function MSP_MIXER_CONFIG:setParam(key, value)
    rfsuite.bg.msp.api.setParam(self.writeDataBuffer, self.writeStructure, key, value)
end

-- Write updated data back using write structure (offloaded to api.lua to avoid duplication)
function MSP_MIXER_CONFIG:writeData()
    rfsuite.bg.msp.api.writeData(WRITE_ID, rfsuite.bg.msp.api.buildWriteRequest, self.writeStructure, self.writeDataBuffer, function() writeCompleteState = true end, nil)
end

-- Fetch data from MSP
function MSP_MIXER_CONFIG:fetchData()
    rfsuite.bg.msp.api.fetchData(READ_ID, rfsuite.bg.msp.api.parseResponse, self.readStructure, #self.readStructure, self.readData, function() readCompleteState = true end, nil, simulatorResponse)
end


return MSP_MIXER_CONFIG
