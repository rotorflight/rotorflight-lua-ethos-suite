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

--[[
local function sportTelemetryPop()
    -- NO de-dup while we diagnose v2: always forward the frame.
    local sensorId, frameId, dataId, value = transport.sportTelemetryPop()
    return sensorId, frameId, dataId, value
end
]]--

transport.mspPoll = function()
    local sensorId, frameId, dataId, value = sportTelemetryPop()
    if not sensorId then return nil end

    -- Accept FC-origin frames; some stacks may emit v2 cont on 0x30 too
    if (sensorId == SPORT_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID)
       and (frameId == REPLY_FRAME_ID or frameId == REQUEST_FRAME_ID) then

        local status = dataId & 0xFF
        local ver    = (status >> 5) & 0x03   -- 0/1=legacy, 2=MSPv2

        if ver == 2 then
            -- SmartPort: we can deliver 5 bytes after status: appId_hi + 4 value bytes
            local app_hi = (dataId >> 8) & 0xFF
            local b0 =  value        & 0xFF
            local b1 = (value >> 8)  & 0xFF
            local b2 = (value >> 16) & 0xFF
            local b3 = (value >> 24) & 0xFF
            local isStart = (status & 0x10) ~= 0

            if isStart then
                -- MSPv2 START header expected by common.lua:
                --   [status][flags][cmd1][cmd2][len1][len2]
                local out = { (status | 0x10) & 0xFF, app_hi, b0, b1, b2, b3 }
                if rfsuite and rfsuite.utils and rfsuite.utils.log then
                    rfsuite.utils.log(
                        string.format(
                            "MSPv2 START frame: status=%02X flags=%02X cmd=%u size=%u",
                            out[1], out[2], (out[4] << 8) | out[3], (out[6] << 8) | out[5]
                        ),
                        "info"
                    )
                    rfsuite.utils.log(
                        string.format("[sp->common v2 START] %02X %02X %02X %02X %02X %02X",
                                      out[1], out[2], out[3], out[4], out[5], out[6]), "debug")
                end
                return out
            else
                -- MSPv2 CONT payload expected by common.lua:
                --   [status][d0][d1][d2][d3][d4]
                local out = { status & 0xFF, app_hi, b0, b1, b2, b3 }
                if rfsuite and rfsuite.utils and rfsuite.utils.log then
                    rfsuite.utils.log(
                        string.format("MSPv2 CONT frame: status=%02X data=[%02X %02X %02X %02X %02X]",
                                      out[1], out[2], out[3], out[4], out[5], out[6]),
                        "info"
                    )
                end
                return out
            end
        end

        -- MSPv0/v1 legacy path (unchanged)
        return {
            dataId & 0xFF, (dataId >> 8) & 0xFF,
            value & 0xFF, (value >> 8) & 0xFF, (value >> 16) & 0xFF, (value >> 24) & 0xFF
        }
    end

    return nil
end




return transport
