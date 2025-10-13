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
local rfsuite = require("rfsuite") 

local transport = {}

local LOCAL_SENSOR_ID = 0x0D
local sport_REMOTE_SENSOR_ID = 0x1B
local FPORT_REMOTE_SENSOR_ID = 0x00
local REQUEST_FRAME_ID = 0x30
local REPLY_FRAME_ID = 0x32

local lastSensorId, lastFrameId, lastDataId, lastValue

-- PUSH THE TELEMETRY FRAME
--[[
    Pushes telemetry data to the sensor.

    This function is used to send telemetry data to a sensor. It can also be called without parameters to check the status of the output buffer.

    @param sensorId  (number) The physical sensor ID.
    @param frameId   (number) The frame ID.
    @param dataId    (number) The data ID.
    @param value     (number) The value to be sent.
    @retval boolean  Returns true if data is queued in the output buffer, false otherwise.
    @retval nil      Returns nil if the telemetry protocol is incorrect.
]]
function transport.sportTelemetryPush(sensorId, frameId, dataId, value)
    return rfsuite.tasks.msp.sensor:pushFrame({physId = sensorId, primId = frameId, appId = dataId, value = value})
end

-- GRAB THE SPORT TELEMETRY FRAME
--[[
    Function: transport.sportTelemetryPop

    Description:
    Pops a received SPORT packet from the queue. Only packets using a data ID within 0x5000 to 0x50FF (frame ID == 0x10), 
    as well as packets with a frame ID equal to 0x32 (regardless of the data ID), will be passed to the LUA telemetry receive queue.

    Returns:
    physId (number) - Physical / remote sensor Id (aka sensorId). 0x00 for FPORT, 0x1B for SPORT.
    primId (number) - Frame ID (should be 0x32 for reply frames).
    appId (number) - Data ID.
    value (number) - The value of the frame.
]]
function transport.sportTelemetryPop()
    local frame = rfsuite.tasks.msp.sensor:popFrame()
    if frame == nil then return nil, nil, nil, nil end
    return frame:physId(), frame:primId(), frame:appId(), frame:value()
end

--[[
    Sends an MSP (Multiwii Serial Protocol) payload via telemetry.

    @param payload (table): A table containing the payload data to be sent.
        - payload[1] (number): The lower byte of the data ID.
        - payload[2] (number): The higher byte of the data ID.
        - payload[3..n] (number): The payload data bytes.

    @return (boolean): Returns true if the telemetry push was successful, false otherwise.
]]
transport.mspSend = function(payload)
    local dataId = payload[1] + (payload[2] << 8)
    local value = 0
    for i = 3, #payload do value = value + (payload[i] << ((i - 3) * 8)) end

    return transport.sportTelemetryPush(LOCAL_SENSOR_ID, REQUEST_FRAME_ID, dataId, value)
end

--[[
    Function: transport.mspRead
    Description: Sends an MSP (Multiwii Serial Protocol) request with the given command.
    Parameters:
        cmd - The command to be sent in the MSP request.
    Returns:
        The response from the mspSendRequest function.
]]
transport.mspRead = function(cmd)
    return rfsuite.tasks.msp.common.mspSendRequest(cmd, {})
end

--[[
    Function: transport.mspWrite
    Description: Sends an MSP (Multiwii Serial Protocol) request with the given command and payload.
    Parameters:
        cmd - The command to be sent.
        payload - The data to be sent with the command.
    Returns:
        The result of the mspSendRequest function.
]]
transport.mspWrite = function(cmd, payload)
    return rfsuite.tasks.msp.common.mspSendRequest(cmd, payload)
end


-- This function retrieves telemetry data from the sportTelemetryPop function of the transport module.
-- It ensures that the same telemetry data is not processed multiple times consecutively by comparing
-- the current data with the last processed data.
-- 
-- @return sensorId, frameId, dataId, value - The telemetry data if it is different from the last processed data, otherwise nil.
local lastSensorId, lastFrameId, lastDataId, lastValue = nil, nil, nil, nil

local function sportTelemetryPop()
    local sensorId, frameId, dataId, value = transport.sportTelemetryPop()
    
    if sensorId and not (sensorId == lastSensorId and frameId == lastFrameId and dataId == lastDataId and value == lastValue) then
        lastSensorId, lastFrameId, lastDataId, lastValue = sensorId, frameId, dataId, value
        return sensorId, frameId, dataId, value
    end
    
    return nil
end


--[[
    Function: transport.mspPoll

    Description:
    This function polls the telemetry data from the sportTelemetryPop function. It processes the data only if the correct sensor and frame IDs match. If the conditions are met, it returns a table containing the processed data. If no data is available or the conditions are not met, it returns nil.

    Returns:
    - A table containing the processed data if the correct sensor and frame IDs match.
    - nil if no data is available or the conditions are not met.

    Example:
    local result = transport.mspPoll()
    if result then
        -- Process the result
    else
        -- Handle the case where no data is available or conditions are not met
    end
]]
transport.mspPoll = function()
    local sensorId, frameId, dataId, value = sportTelemetryPop()

    -- Return nil if no data is available
    if not sensorId then
        return nil
    end

    -- Process only if the correct sensor and frame ID match
    if (sensorId == sport_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID) and frameId == REPLY_FRAME_ID then
        return {
            dataId & 0xFF,
            (dataId >> 8) & 0xFF,
            value & 0xFF,
            (value >> 8) & 0xFF,
            (value >> 16) & 0xFF,
            (value >> 24) & 0xFF
        }
    end

    return nil  -- Return nil if conditions are not met
end


return transport
