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

    if (sensorId == SPORT_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID) and frameId == REPLY_FRAME_ID then return {dataId & 0xFF, (dataId >> 8) & 0xFF, value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF} end

    return nil
end

return transport
