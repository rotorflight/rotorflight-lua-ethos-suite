--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


-- Optimized locals to reduce global/table lookups
local os_clock = os.clock
local utils = rfsuite.utils
local MSP_PROTOCOL_VERSION = rfsuite.config.mspProtocolVersion or 1
local API_ENGINE_DEFAULT = "v2"

local msp = {}

msp.activeProtocol = nil      -- Current telemetry protocol type in use
msp.onConnectChecksInit = true -- Flag to run initial checks on telemetry connect

local protocol = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/protocols.lua"))()
local helpers = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/helpers.lua"))()
local proto_logger = protocol.getProtoLogger and protocol.getProtoLogger() or nil

local telemetryTypeChanged = false -- Set when switching CRSF/S.Port/etc.

local mspQueue

-- Protocol parameters for current telemetry type
msp.protocol = protocol.getProtocol()

-- Expose helper functions
msp.helpers = helpers

-- Load all transport modules
msp.protocolTransports = {}
for i, v in pairs(protocol.getTransports()) do
    msp.protocolTransports[i] = assert(loadfile(v))()
end

-- Bind protocol transport functions
local transport = msp.protocolTransports[msp.protocol.mspProtocol]
msp.protocol.mspRead  = transport.mspRead
msp.protocol.mspSend  = transport.mspSend
msp.protocol.mspWrite = transport.mspWrite
msp.protocol.mspPoll  = transport.mspPoll

-- Load MSP queue with protocol settings
mspQueue = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/mspQueue.lua"))()
msp.mspQueue = mspQueue
mspQueue.maxRetries   = msp.protocol.maxRetries
mspQueue.loopInterval = 0                -- Queue processing rate
mspQueue.copyOnAdd    = true             -- Clone messages on enqueue
mspQueue.interMessageDelay = 0.05         -- Delay between messages
mspQueue.timeout      = msp.protocol.mspQueueTimeout or 2.0
mspQueue.drainAfterReplyMss = 0.05         -- No drain delay after reply
mspQueue.drainMaxPolls = 5                 -- Max polls to wait during drain
mspQueue.busyWarningThreshold = msp.protocol.mspQueueBusyWarning or 8 -- Soft pressure signal only
mspQueue.maxQueueDepth = msp.protocol.mspQueueMaxDepth or 20            -- Hard cap (0 = disabled)
mspQueue.busyStatusCooldown = msp.protocol.mspQueueBusyStatusCooldown or 0.35

-- Load helpers and API handlers
msp.mspHelper = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/mspHelper.lua"))()
local apiLoader = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api.lua"))()
msp.api       = apiLoader
msp.apiEngine = "v2"
msp.common    = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/common.lua"))()
-- Snapshot protocol version at load; later changes should call setProtocolVersion.
msp.common.setProtocolVersion(MSP_PROTOCOL_VERSION or 1)

-- Expose protocol logger
msp.proto_logger = proto_logger

function msp.enableProtoLog(on)
    if proto_logger and proto_logger.enable then
        proto_logger.enable(on)
        return proto_logger.enabled
    end
    return false
end

function msp.setApiEngine(name)
    if type(name) == "string" then
        local requested = string.lower(name)
        if requested == "1" or requested == "v1" or requested == "apiv1" then
            utils.log("[msp] apiv1 removed; forcing v2", "info")
        end
    end
    msp.api = apiLoader
    msp.apiEngine = "v2"
    utils.log("[msp] API engine set to " .. tostring(msp.apiEngine), "info")
    return msp.apiEngine
end

function msp.getApiEngine()
    return msp.apiEngine
end

msp.setApiEngine(API_ENGINE_DEFAULT)


-- Delay handling for clean protocol reset
local delayDuration  = 2
local delayStartTime = nil
local delayPending   = false

-- Main MSP poll loop (called by script wakeups)
function msp.wakeup()

    local session = rfsuite.session
    -- enable logging
    -- rfsuite.tasks.msp.enableProtoLog(true)

    -- Nothing to do if no telemetry sensor
    if session.telemetrySensor == nil then return end

    -- Apply delay after reset request
    if session.resetMSP and not delayPending then
        delayStartTime = os_clock()
        delayPending = true
        session.resetMSP = false
        utils.log("Delaying msp wakeup for " .. delayDuration .. " seconds", "info")
        return
    end

    -- Hold off processing while in delay period
    if delayPending then
        if os_clock() - delayStartTime >= delayDuration then
            utils.log("Delay complete; resuming msp wakeup", "info")
            delayPending = false
        else
            mspQueue:clear()
            return
        end
    end

    msp.activeProtocol = session.telemetryType

    -- Telemetry type changed (e.g., CRSF <-> S.Port)
    if telemetryTypeChanged == true then

        msp.protocol = protocol.getProtocol()

        local transport = msp.protocolTransports[msp.protocol.mspProtocol]
        msp.protocol.mspRead  = transport.mspRead
        msp.protocol.mspSend  = transport.mspSend
        msp.protocol.mspWrite = transport.mspWrite
        msp.protocol.mspPoll  = transport.mspPoll

        utils.session()
        msp.onConnectChecksInit = true
        telemetryTypeChanged = false
    end

    -- If telemetry was disconnected, re-run init handlers
    if session.telemetrySensor ~= nil and session.telemetryState == false then
        utils.session()
        msp.onConnectChecksInit = true
    end

    -- Run queue when connected, otherwise clear it
    if session.telemetryState == true then
        mspQueue:processQueue()
    else
        mspQueue:clear()
    end
end

-- Mark that protocol should be reloaded on next wakeup
function msp.setTelemetryTypeChanged()
    telemetryTypeChanged = true
end

-- Reset MSP state and transport
function msp.reset()
    mspQueue:clear()
    msp.activeProtocol = nil
    msp.onConnectChecksInit = true
    delayStartTime = nil
    delayPending = false
    local activeTransport = msp.protocolTransports[msp.protocol.mspProtocol]
    if activeTransport and activeTransport.reset then activeTransport.reset() end
end

return msp
