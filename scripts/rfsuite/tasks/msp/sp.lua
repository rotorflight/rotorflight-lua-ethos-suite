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
    return mspSendRequest(cmd, {})
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
    return mspSendRequest(cmd, payload)
end

--[[
    Function: sportTelemetryPop
    Description: Continuously polls for telemetry data from the sport transport layer. 
                 It returns the sensorId, frameId, dataId, and value when new data is detected.
    Returns: 
        - sensorId: The ID of the sensor.
        - frameId: The ID of the frame.
        - dataId: The ID of the data.
        - value: The value of the data.
    Usage: 
        local sensorId, frameId, dataId, value = sportTelemetryPop()
        if sensorId then
            -- Process the telemetry data
        end
]]
local function sportTelemetryPop()
    while true do
        local sensorId, frameId, dataId, value = transport.sportTelemetryPop()
        if not sensorId then
            return nil
        elseif (lastSensorId == sensorId) and (lastFrameId == frameId) and (lastDataId == dataId) and (lastValue == value) then
            -- Keep checking
        else
            lastSensorId = sensorId
            lastFrameId = frameId
            lastDataId = dataId
            lastValue = value
            return sensorId, frameId, dataId, value
        end
    end
end

--[[
    Function: transport.mspPoll

    Description:
    Continuously polls for telemetry data from the sport or FPORT remote sensor. 
    When a valid telemetry frame is received, it extracts the data and value, 
    constructs a payload table, and returns it.

    Returns:
    - payload (table): A table containing the extracted data and value from the telemetry frame.
    - nil: If no sensorId is received.

    Notes:
    - The function runs in an infinite loop until a valid telemetry frame is received or sensorId is nil.
]]
transport.mspPoll = function()
    while true do
        local sensorId, frameId, dataId, value = sportTelemetryPop()
        if (sensorId == sport_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID) and frameId == REPLY_FRAME_ID then
            local payload = {}
            payload[1] = dataId & 0xFF
            dataId = dataId >> 8
            payload[2] = dataId & 0xFF
            payload[3] = value & 0xFF
            value = value >> 8
            payload[4] = value & 0xFF
            value = value >> 8
            payload[5] = value & 0xFF
            value = value >> 8
            payload[6] = value & 0xFF
            return payload
        elseif sensorId == nil then
            return nil
        end
    end
end

return transport
