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
]]--

-- Constants for MSP Commands
local MSP_API_CMD = 42  -- Command identifier for MSP Mixer Config
local MSP_API_SIMULATOR_RESPONSE = {0, 0, 0, 0, 0, 2, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}  -- Default simulator response
local MSP_MIN_BYTES = 19

-- Define the MSP response data structure
local MSP_API_STRUCTURE = {
    { field = "main_rotor_dir", type = "U8" },
    { field = "tail_rotor_mode", type = "U8" },
    { field = "tail_motor_idle", type = "U8" },
    { field = "tail_center_trim", type = "U16" },
    { field = "swash_type", type = "U8" },
    { field = "swash_ring", type = "U8" },
    { field = "swash_phase", type = "U16" },
    { field = "swash_pitch_limit", type = "U16" },
    { field = "swash_trim_0", type = "U16" },
    { field = "swash_trim_1", type = "U16" },
    { field = "swash_trim_2", type = "U16" },
    { field = "swash_tta_precomp", type = "U8" },
    { field = "swash_geo_correction", type = "U8" }
}

-- Variable to store parsed MSP data
local mspData = nil

-- Function to initiate MSP read operation
local function read()
    local message = {
        command = MSP_API_CMD,  -- Specify the MSP command
        processReply = function(self, buf)
            -- Parse the MSP data using the defined structure
            mspData = rfsuite.bg.msp.api.parseMSPData(buf, MSP_API_STRUCTURE)
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE
    }
    -- Add the message to the processing queue
    rfsuite.bg.msp.mspQueue:add(message)
end

-- Function to return the parsed MSP data
local function data()
    return mspData
end

-- Function to check if the read operation is complete
local function readComplete()
    if mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES then
            return true
    end    
    return false
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then
        return mspData['parsed'][fieldName]
    end
    return nil
end

-- Return the module's API functions
return {
    data = data,
    read = read,
    readComplete = readComplete,
    readVersion = readVersion,
    readValue = readValue
}
