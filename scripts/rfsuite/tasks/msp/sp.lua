--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local transport = {}

local LOCAL_SENSOR_ID = 0x0D
local SPORT_REMOTE_SENSOR_ID = 0x1B
local FPORT_REMOTE_SENSOR_ID = 0x00
local REQUEST_FRAME_ID = 0x30
local REPLY_FRAME_ID = 0x32

local lastSensorId, lastFrameId, lastDataId, lastValue

local sensor

function transport.sportTelemetryPush(sensorId, frameId, dataId, value) 
    if not sensor then sensor = sport.getSensor({primId = 0x32}) end
    return sensor:pushFrame({physId = sensorId, primId = frameId, appId = dataId, value = value}) 
end

function transport.sportTelemetryPop()
    if not sensor then sensor = sport.getSensor({primId = 0x32}) end
    local frame = sensor:popFrame()
    if frame == nil then return nil, nil, nil, nil end
    return frame:physId(), frame:primId(), frame:appId(), frame:value()
end

transport.mspSend = function(payload)
    local dataId = (payload[1] or 0) | ((payload[2] or 0) << 8)
    local v3 = payload[3] or 0
    local v4 = payload[4] or 0
    local v5 = payload[5] or 0
    local v6 = payload[6] or 0
    local value = v3 | (v4 << 8) | (v5 << 16) | (v6 << 24)

    return transport.sportTelemetryPush(LOCAL_SENSOR_ID, REQUEST_FRAME_ID, dataId, value)
end

transport.mspRead = function(cmd) return rfsuite.tasks.msp.common.mspSendRequest(cmd, {}) end

transport.mspWrite = function(cmd, payload) return rfsuite.tasks.msp.common.mspSendRequest(cmd, payload) end

local lastSensorId, lastFrameId, lastDataId, lastValue = nil, nil, nil, nil

local function sportTelemetryPop()
    local sensorId, frameId, dataId, value = transport.sportTelemetryPop()


    if sensorId and not (sensorId == lastSensorId and frameId == lastFrameId and dataId == lastDataId and value == lastValue) then
        lastSensorId, lastFrameId, lastDataId, lastValue = sensorId, frameId, dataId, value
        return sensorId, frameId, dataId, value
    end

    return nil
end

transport.mspPoll = function()
    local sensorId, frameId, dataId, value = sportTelemetryPop()
    if not sensorId then return nil end

    -- Accept FC-origin frames; for v2 some stacks use 0x30 as well as 0x32
    if (sensorId == SPORT_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID)
       and (frameId == REPLY_FRAME_ID or frameId == REQUEST_FRAME_ID) then

        local status = dataId & 0xFF
        local ver    = (status >> 5) & 0x03  -- 2 = MSPv2

        if ver == 2 then
            -- S.Port reply word (little endian):
            -- value = 0xVVVVVVVV → v0 = LSB … v3 = MSB
            local v0 =  value        & 0xFF  -- first data/req byte
            local v1 = (value >> 8)  & 0xFF  -- flags / data
            local v2 = (value >> 16) & 0xFF  -- SIZE (observed on your POPs)
            local v3 = (value >> 24) & 0xFF  -- extra / data
            local start = (status & 0x10) ~= 0

            if start then
                -- MSPv2 START: byte2 must be SIZE, then data bytes.
                -- Your frames look like: v2=size, payload in v0,v1,v3.
                rfsuite.utils.log("MSPv2 START frame received: size=" .. tostring(v2),"info")
                return { status, v2, v0, v1, v3, 0x00 }
            else
                -- MSPv2 CONT: status then 4 data bytes
                rfsuite.utils.log("MSPv2 CONT frame received " .. string.format("data=0x%02X%02X%02X%02X", v0, v1, v2, v3),"info")
                return { status, v0, v1, v2, v3, 0x00 }
            end
        end

        -- MSPv0/v1 (legacy) — unchanged mapping that already works for you
        return {
            dataId & 0xFF, (dataId >> 8) & 0xFF,
            value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF
        }
    end

    return nil
end



return transport
