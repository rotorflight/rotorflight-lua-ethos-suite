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
local API_NAME = "TELEMETRY_CONFIG" -- API name (must be same as filename)
local MSP_API_CMD_READ = 73 -- Command identifier 
local MSP_API_CMD_WRITE = 74 -- Command identifier 
local MSP_REBUILD_ON_WRITE = false -- Rebuild the payload on write 

-- Check this url for some usefull id numbers when associated these sensors to the correct telemetry sensors "set telemetry_sensors"
-- https://github.com/rotorflight/rotorflight-firmware/blob/c7cad2c86fd833fe4bce76728f4914602614058d/src/main/telemetry/sensors.h#L34C15-L34C24

-- in tasks/telemetry/telemetry.lua we specify set_telemetry_sensors with a map to these id's and use them
-- when filling telem_sensor_slots.

-- Define the MSP response data structures with simResponse
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "telemetry_inverted",        type = "U8",  apiVersion = 12.06 , simResponse = {0}},
    {field = "halfDuplex",                type = "U8",  apiVersion = 12.06 , simResponse = {1}},
    {field = "enableSensors",             type = "U32", apiVersion = 12.06 , simResponse = {0, 0, 0, 0}},  -- not used in 12.08 and higher
    {field = "pinSwap",                   type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "crsf_telemetry_mode",       type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "crsf_telemetry_link_rate",  type = "U16", apiVersion = 12.08 , simResponse = {250, 0}},
    {field = "crsf_telemetry_link_ratio", type = "U16", apiVersion = 12.08 , simResponse = {8, 0}},
    {field = "telem_sensor_slot_1",       type = "U8",  apiVersion = 12.08 , simResponse = {3}},
    {field = "telem_sensor_slot_2",       type = "U8",  apiVersion = 12.08 , simResponse = {4}},
    {field = "telem_sensor_slot_3",       type = "U8",  apiVersion = 12.08 , simResponse = {5}},
    {field = "telem_sensor_slot_4",       type = "U8",  apiVersion = 12.08 , simResponse = {6}},
    {field = "telem_sensor_slot_5",       type = "U8",  apiVersion = 12.08 , simResponse = {8}},
    {field = "telem_sensor_slot_6",       type = "U8",  apiVersion = 12.08 , simResponse = {8}},
    {field = "telem_sensor_slot_7",       type = "U8",  apiVersion = 12.08 , simResponse = {89}},
    {field = "telem_sensor_slot_8",       type = "U8",  apiVersion = 12.08 , simResponse = {90}},
    {field = "telem_sensor_slot_9",       type = "U8",  apiVersion = 12.08 , simResponse = {91}},
    {field = "telem_sensor_slot_10",      type = "U8",  apiVersion = 12.08 , simResponse = {99}},
    {field = "telem_sensor_slot_11",      type = "U8",  apiVersion = 12.08 , simResponse = {95}},
    {field = "telem_sensor_slot_12",      type = "U8",  apiVersion = 12.08 , simResponse = {96}},
    {field = "telem_sensor_slot_13",      type = "U8",  apiVersion = 12.08 , simResponse = {60}},
    {field = "telem_sensor_slot_14",      type = "U8",  apiVersion = 12.08 , simResponse = {15}},
    {field = "telem_sensor_slot_15",      type = "U8",  apiVersion = 12.08 , simResponse = {42}},
    {field = "telem_sensor_slot_16",      type = "U8",  apiVersion = 12.08 , simResponse = {93}},
    {field = "telem_sensor_slot_17",      type = "U8",  apiVersion = 12.08 , simResponse = {50}},
    {field = "telem_sensor_slot_18",      type = "U8",  apiVersion = 12.08 , simResponse = {51}},
    {field = "telem_sensor_slot_19",      type = "U8",  apiVersion = 12.08 , simResponse = {52}},
    {field = "telem_sensor_slot_20",      type = "U8",  apiVersion = 12.08 , simResponse = {17}},
    {field = "telem_sensor_slot_21",      type = "U8",  apiVersion = 12.08 , simResponse = {18}},
    {field = "telem_sensor_slot_22",      type = "U8",  apiVersion = 12.08 , simResponse = {19}},
    {field = "telem_sensor_slot_23",      type = "U8",  apiVersion = 12.08 , simResponse = {23}},
    {field = "telem_sensor_slot_24",      type = "U8",  apiVersion = 12.08 , simResponse = {22}},
    {field = "telem_sensor_slot_25",      type = "U8",  apiVersion = 12.08 , simResponse = {36}},
    {field = "telem_sensor_slot_26",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_27",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_28",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_29",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_30",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_31",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_32",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_33",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_34",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_35",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_36",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_37",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_38",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_39",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
    {field = "telem_sensor_slot_40",      type = "U8",  apiVersion = 12.08 , simResponse = {0}},
}


-- Process structure in one pass
local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE =
    rfsuite.tasks.msp.api.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- set read structure
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

-- Variable to store parsed MSP data
local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

-- Create a new instance
local handlers = rfsuite.tasks.msp.api.createHandlers()

-- Variables to store optional the UUID and timeout for payload
local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

-- Function to initiate MSP read operation
local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_READ,
        processReply = function(self, buf)
            local structure = MSP_API_STRUCTURE_READ
            rfsuite.tasks.msp.api.parseMSPData(buf, structure, nil, nil, function(result)
                mspData = result

                if #buf >= MSP_MIN_BYTES then
                    local completeHandler = handlers.getCompleteHandler()
                    if completeHandler then completeHandler(self, buf) end
                end
            end)
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT  
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)

    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = suppliedPayload or rfsuite.tasks.msp.api.buildWritePayload(API_NAME, payloadData,MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE),
        processReply = function(self, buf)
            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then completeHandler(self, buf) end
            mspWriteComplete = true
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = {},
        uuid = MSP_API_UUID,
        timeout = MSP_API_TIMEOUT  
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Function to get the value of a specific field from MSP data
local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

-- Function to set a value dynamically
local function setValue(fieldName, value)
    payloadData[fieldName] = value
end

-- Function to check if the read operation is complete
local function readComplete()
    return mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES
end

-- Function to check if the write operation is complete
local function writeComplete()
    return mspWriteComplete
end

-- Function to reset the write completion status
local function resetWriteStatus()
    mspWriteComplete = false
end

-- Function to return the parsed MSP data
local function data()
    return mspData
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
    read = read,
    write = write,
    readComplete = readComplete,
    writeComplete = writeComplete,
    readValue = readValue,
    setValue = setValue,
    resetWriteStatus = resetWriteStatus,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}
