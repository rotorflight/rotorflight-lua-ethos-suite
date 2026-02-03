--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local protocol = {}

local supportedProtocols = {
  sport = {
    mspTransport       = "sp.lua",    -- Lua transport module to load for this protocol
    mspProtocol        = "sport",     -- Name used by MSP layer to identify the wire protocol
    maxTxBufferSize    = 6,           -- Maximum bytes we are allowed to send in one MSP packet
    maxRxBufferSize    = 6,           -- Maximum bytes we expect to receive per MSP packet
    maxRetries         = 10,          -- Max number of resend attempts for a failed MSP command
    saveTimeout        = 20.0,        -- Timeout (seconds) for MSP save/write operations
    pageReqTimeout     = 20,          -- Timeout when requesting UI/CMS pages from the FC
    mspIntervalOveride = 0.25,        -- Minimum delay between MSP writes (rate limiting)
    mspQueueTimeout    = 4.0,         -- Time allowed for the MSP queue to remain busy before forcing a reset
    mspPollBudget      = 0.15         -- Max time per cycle to poll MSP replies before yielding
  },

  crsf = {
    mspTransport       = "crsf.lua",  -- Transport module for CRSF link
    mspProtocol        = "crsf",      -- MSP-over-CRSF protocol identifier
    maxTxBufferSize    = 8,           -- CRSF allows slightly larger write packets than S.Port
    maxRxBufferSize    = 58,          -- CRSF's MSP stream can deliver large response frames
    maxRetries         = 5,           -- CRSF is reliable, so fewer retries are needed
    saveTimeout        = 20.0,        -- Timeout (seconds) for MSP save/write operations
    pageReqTimeout     = 20,          -- Timeout when requesting CMS pages via CRSF
    mspIntervalOveride = 0.25,        -- Minimum delay between MSP sends
    mspQueueTimeout    = 2.0,         -- Shorter queue timeout (CRSF is low-latency)
    mspPollBudget      = 0.1          -- Time slice for polling MSP replies
  },
}

function protocol.getProtocol()
    if rfsuite.session and rfsuite.session.telemetryType then
        if rfsuite.session.telemetryType == "crsf" then
            return supportedProtocols.crsf
        end
    end
    return supportedProtocols.sport
end

function protocol.getTransports()
    local transport = {}
    for i, v in pairs(supportedProtocols) do
        transport[i] = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/" .. v.mspTransport
    end
    return transport
end


-- Optional protocol logger (writes raw TX/RX frames to /LOGS/msp_proto.log)
-- Enabled at runtime via: rfsuite.tasks.msp.enableProtoLog(true)
local proto_logger = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/proto_logger.lua"))()

function protocol.enableProtoLog(on)
    proto_logger.enable(on)
    return proto_logger.enabled
end

function protocol.getProtoLogger()
    return proto_logger
end

return protocol
