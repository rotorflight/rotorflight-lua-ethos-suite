--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local transport = {}
local os_clock = os.clock

-- FrSky / F.Port identifiers
local LOCAL_SENSOR_ID        = 0x0D   -- Our device's sensor ID when sending
local SPORT_REMOTE_SENSOR_ID = 0x1B   -- Incoming MSP-over-S.PORT sensor ID
local FPORT_REMOTE_SENSOR_ID = 0x00   -- Incoming MSP-over-F.PORT sensor ID
local REQUEST_FRAME_ID       = 0x30   -- Outbound MSP request frame
local REPLY_FRAME_ID         = 0x32   -- Inbound MSP reply frame
local MSP_STARTFLAG          = (1 << 4) -- Set on start packet

-- State for reply frame assembly
local in_reply = false
local expect_seq = nil

-- Cached sensor handle
local sensor

-- Localize session for faster access
local session = rfsuite.session

-- Convert a 16-bit dataId + 32-bit value into 6 bytes as per FrSky subframe format
local function _map_subframe(dataId, value)
    return {
        dataId & 0xFF,
        (dataId >> 8) & 0xFF,
        value & 0xFF,
        (value >> 8) & 0xFF,
        (value >> 16) & 0xFF,
        (value >> 24) & 0xFF,
    }
end

-- Push a telemetry frame using FrSky SPORT / FPort API
function transport.sportTelemetryPush(sensorId, frameId, dataId, value)
     
    if not sensor then
        local activeModule = rfsuite.session.telemetryModuleNumber or 0   -- keep full lookup
        sensor = sport.getSensor({module = activeModule, primId = REPLY_FRAME_ID})
    end
    return sensor:pushFrame({physId = sensorId, primId = frameId, appId = dataId, value = value})
end

-- Pop next telemetry frame
function transport.sportTelemetryPop()
    if not sensor then
        local activeModule = rfsuite.session.telemetryModuleNumber or 0   -- keep full lookup
        sensor = sport.getSensor({module = activeModule, primId = REPLY_FRAME_ID})
        return nil, nil, nil, nil
    end

    local frame = sensor:popFrame()
    if frame == nil then return nil, nil, nil, nil end
    return frame:physId(), frame:primId(), frame:appId(), frame:value()
end

-- MSP send function: Pack the payload into a FrSky DATAID + 32-bit VALUE frame
transport.mspSend = function(payload)
    -- First two bytes form dataId
    local dataId = (payload[1] or 0) | ((payload[2] or 0) << 8)
    -- Next four bytes form 32-bit value
    local v3, v4, v5, v6 = payload[3] or 0, payload[4] or 0, payload[5] or 0, payload[6] or 0
    local value = v3 | (v4 << 8) | (v5 << 16) | (v6 << 24)
    return transport.sportTelemetryPush(LOCAL_SENSOR_ID, REQUEST_FRAME_ID, dataId, value)
end

-- MSP read/write wrappers
function transport.mspRead(cmd)
    return rfsuite.tasks.msp.common.mspSendRequest(cmd, {})
end

function transport.mspWrite(cmd, payload)
    return rfsuite.tasks.msp.common.mspSendRequest(cmd, payload)
end

-- Poll FrSky telemetry for incoming MSP reply frames
function transport.mspPoll()
    local mspTask = rfsuite.tasks.msp
    local protoCfg = mspTask and mspTask.protocol or {}
    local budget = protoCfg.mspTransportPollBudgetSeconds or 0.004
    local deadline = (budget and budget > 0) and (os_clock() + budget) or nil

    while true do
        if deadline and os_clock() >= deadline then return nil end
        local sensorId, frameId, dataId, value = transport.sportTelemetryPop()
        if not sensorId then return nil end

        -- Only process reply frames from recognized MSP sensors
        -- Inline _isInboundReply check
        if not ((sensorId == SPORT_REMOTE_SENSOR_ID or sensorId == FPORT_REMOTE_SENSOR_ID) and frameId == REPLY_FRAME_ID) then
            goto continue
        end

        -- Decode status byte directly from dataId (low byte)
        local status = dataId & 0xFF
        local seq = status & 0x0F

        -- Start of reply frame
        if (status & MSP_STARTFLAG) ~= 0 then
            in_reply = true
            expect_seq = seq
            return _map_subframe(dataId, value)

        -- Continuation frame
        elseif in_reply then
            if expect_seq ~= nil then
                local next_seq = (expect_seq + 1) & 0x0F

                -- Duplicate: ignore
                if seq == expect_seq then
                    goto continue

                -- Out-of-order: abort reply assembly
                elseif seq ~= next_seq then
                    in_reply = false
                    expect_seq = nil
                    goto continue
                end
            end

            -- Good continuation frame
            expect_seq = seq
            return _map_subframe(dataId, value)
        end

        ::continue::
    end
end

-- Clear cached sensor so it will be re-acquired
function transport.reset()
    sensor = nil
    in_reply = false
    expect_seq = nil
end

return transport
