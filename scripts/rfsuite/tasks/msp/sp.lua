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
local SMARTPORT_REMOTE_SENSOR_ID = 0x1B
local FPORT_REMOTE_SENSOR_ID = 0x00
local REQUEST_FRAME_ID = 0x30
local REPLY_FRAME_ID = 0x32

local lastSensorId, lastFrameId, lastDataId, lastValue

-- PUSH THE TELEMETRY FRAME
function transport.sportTelemetryPush(sensorId, frameId, dataId, value)
    -- OpenTX:
    -- When called without parameters, it will only return the status of the output buffer without sending anything.
    --   Equivalent in Ethos may be:   sensor:idle() ???
    -- @param sensorId  physical sensor ID
    -- @param frameId   frame ID
    -- @param dataId        data ID
    -- @param value         value
    -- @retval boolean  data queued in output buffer or not.
    -- @retval nil          incorrect telemetry protocol.  (added in 2.3.4)
    return rfsuite.bg.msp.sensor:pushFrame({
        physId = sensorId,
        primId = frameId,
        appId = dataId,
        value = value
    })
end

-- GRAB THE SPORT TELEMETRY FRAME
function transport.sportTelemetryPop()
    -- Pops a received SPORT packet from the queue. Please note that only packets using a data ID within 0x5000 to 0x50FF (frame ID == 0x10), as well as packets with a frame ID equal 0x32 (regardless of the data ID) will be passed to the LUA telemetry receive queue.
    local frame = rfsuite.bg.msp.sensor:popFrame()
    if frame == nil then return nil, nil, nil, nil end
    -- physId = physical / remote sensor Id (aka sensorId)
    --   0x00 for FPORT, 0x1B for SmartPort
    -- primId = frame ID  (should be 0x32 for reply frames)
    -- appId = data Id
    return frame:physId(), frame:primId(), frame:appId(), frame:value()
end

transport.mspSend = function(payload)
    local dataId = payload[1] + (payload[2] << 8)
    local value = 0
    for i = 3, #payload do value = value + (payload[i] << ((i - 3) * 8)) end

    return transport.sportTelemetryPush(LOCAL_SENSOR_ID, REQUEST_FRAME_ID,
                                        dataId, value)
end

transport.mspRead = function(cmd)
    return mspSendRequest(cmd, {})
end

transport.mspWrite = function(cmd, payload)
    return mspSendRequest(cmd, payload)
end

-- Discards duplicate data from lua input buffer
local function smartPortTelemetryPop()
    while true do
        local sensorId, frameId, dataId, value = transport.sportTelemetryPop()
        if not sensorId then
            return nil
        elseif (lastSensorId == sensorId) and (lastFrameId == frameId) and
            (lastDataId == dataId) and (lastValue == value) then
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

transport.mspPoll = function()
    while true do
        local sensorId, frameId, dataId, value = smartPortTelemetryPop()
        if (sensorId == SMARTPORT_REMOTE_SENSOR_ID or sensorId ==
            FPORT_REMOTE_SENSOR_ID) and frameId == REPLY_FRAME_ID then
            -- --rfsuite.utils.log("sensorId:0x"..string.format("%X", sensorId).." frameId:0x"..string.format("%X", frameId).." dataId:0x"..string.format("%X", dataId).." value:0x"..string.format("%X", value))
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
            -- for i=1,#payload do
            --        --rfsuite.utils.log(  "["..string.format("%u", i).."]:  0x"..string.format("%X", payload[i]))
            -- end
            return payload
        elseif sensorId == nil then
            return nil
        end
    end
end

return transport
