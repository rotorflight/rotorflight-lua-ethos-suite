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

-- MSPv2 assembly state
local v2_inflight  = false
local v2_remaining = 0
local v2_req       = nil           -- tracks request id (v0)
local v2_seq       = nil           -- low 4 bits of status
local function v2_get_seq(st) return st & 0x0F end

local lastSensorId, lastFrameId, lastDataId, lastValue

local sensor

local function _isInboundReply(sensorId, frameId)
  return (sensorId == SPORT_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID)
         and frameId == REPLY_FRAME_ID
end

local function _map_subframe(dataId, value)
  return {
    dataId        & 0xFF,              -- HEAD (seq | start | error)
    (dataId >> 8) & 0xFF,              -- NEXT0 (size/cmd on START, data[0] on CONT)
    value         & 0xFF,              -- NEXT1
    (value >> 8)  & 0xFF,              -- NEXT2
    (value >> 16) & 0xFF,              -- NEXT3
    (value >> 24) & 0xFF,              -- NEXT4
  }
end

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


-- Replace sportTelemetryPop() with the simple, no-dedup version
local function sportTelemetryPop()
  local sensorId, frameId, dataId, value = transport.sportTelemetryPop()
  return sensorId, frameId, dataId, value
end


transport.mspPoll = function()
    local sensorId, frameId, dataId, value = sportTelemetryPop()
    if not sensorId then return nil end

    -- Only FC replies
    if not ( (sensorId == SPORT_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID)
             and frameId == REPLY_FRAME_ID ) then
        return nil
    end

    local status = dataId & 0xFF
    local app_hi = (dataId >> 8) & 0xFF
    local b0 =  value        & 0xFF
    local b1 = (value >> 8)  & 0xFF
    local b2 = (value >> 16) & 0xFF
    local b3 = (value >> 24) & 0xFF

    -- Use the negotiated/forced protocol version from common.lua (not reply bits)
    local pv = (rfsuite and rfsuite.tasks and rfsuite.tasks.msp and
                rfsuite.tasks.msp.common and rfsuite.tasks.msp.common.getProtocolVersion)
               and rfsuite.tasks.msp.common.getProtocolVersion() or 1

    if pv == 2 then
        local isStart = (status & 0x10) ~= 0
        if isStart then
            -- v2 START: [status][flags][cmd1][cmd2][len1][len2]
            local out = { status, app_hi, b0, b1, b2, b3 }
            -- (optional logging)
            return out
        else
            -- v2 CONT: [status][d0][d1][d2][d3][d4]
            local out = { status, app_hi, b0, b1, b2, b3 }
            -- (optional logging)
            return out
        end
    end

    -- MSPv1 (technically correct): always forward the exact 6 on-wire bytes
    local out = { status, app_hi, b0, b1, b2, b3 }
    return out
end





return transport
