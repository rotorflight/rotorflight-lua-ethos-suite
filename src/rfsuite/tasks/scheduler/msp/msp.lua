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

msp.activeProtocol = nil
msp.onConnectChecksInit = true

local protocol = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/protocols.lua"))()
local helpers = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/helpers.lua"))()
local proto_logger = nil
local telemetryTypeChanged = false
local mspQueue

msp.bus = rfsuite.bus
msp.genericActions = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/generic_actions.lua"))()
msp.genericActions.register(msp.bus)
msp.protocol = protocol.getProtocol()
msp.helpers = helpers

local transportPaths = protocol.getTransports()
msp.protocolTransports = {}

local function loadTransportModule(transportName)
    local transportModule = msp.protocolTransports[transportName]
    local transportPath
    if transportModule then return transportModule end
    transportPath = transportPaths[transportName]
    if not transportPath then return nil end
    transportModule = assert(loadfile(transportPath))()
    msp.protocolTransports[transportName] = transportModule
    return transportModule
end

local function clearInactiveTransports(activeName)
    for transportName, transportModule in pairs(msp.protocolTransports) do
        if transportName ~= activeName then
            if transportModule and transportModule.reset then transportModule.reset() end
            msp.protocolTransports[transportName] = nil
        end
    end
end

local function bindActiveTransport()
    local transportName = msp.protocol and msp.protocol.mspProtocol
    local transport = transportName and loadTransportModule(transportName)
    if not transport then return nil end

    clearInactiveTransports(transportName)
    msp.protocol.mspRead = transport.mspRead
    msp.protocol.mspSend = transport.mspSend
    msp.protocol.mspWrite = transport.mspWrite

    -- Treat every valid transport packet as reply progress. The queue's resend
    -- backoff is measured from the latest fragment instead of only the original
    -- request, preventing a long fragmented response from being restarted while
    -- it is still arriving. No SD-card logging occurs in this hot path.
    local rawPoll = transport.mspPoll
    msp.protocol.mspPoll = function(...)
        local packet = rawPoll(...)
        if packet ~= nil and mspQueue and mspQueue.currentMessage then
            mspQueue.lastTimeCommandSent = os_clock()
        end
        return packet
    end

    return transport
end

bindActiveTransport()

mspQueue = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/mspQueue.lua"))()
msp.mspQueue = mspQueue

local function applyProtocolQueueSettings()
    local active = msp.protocol or {}
    mspQueue.maxRetries = active.maxRetries or 3
    mspQueue.loopInterval = 0
    mspQueue.copyOnAdd = true
    mspQueue.interMessageDelay = active.mspQueueInterMessageDelay or 0.05
    mspQueue.timeout = active.mspQueueTimeout or 2.0
    mspQueue.rxInactivityTimeout = active.mspRxInactivityTimeout or 0.9
    mspQueue.retryBackoff = active.mspRxInactivityTimeout or 0.9
    mspQueue.drainAfterReplyMs = active.mspQueueDrainAfterReplyMs or 0.03
    mspQueue.drainMaxPolls = active.mspQueueDrainMaxPolls or 5
    mspQueue.busyWarningThreshold = active.mspQueueBusyWarning or 8
    mspQueue.maxQueueDepth = active.mspQueueMaxDepth or 20
    mspQueue.busyStatusCooldown = active.mspQueueBusyStatusCooldown or 0.35
end

applyProtocolQueueSettings()

msp.mspHelper = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/mspHelper.lua"))()
local apiLoader = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api.lua"))()
msp.api = apiLoader
msp.apiEngine = "v2"
msp.common = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/common.lua"))()
msp.common.setProtocolVersion(MSP_PROTOCOL_VERSION or 1)

function msp.getApiCore()
    if not msp.apicore then
        msp.apicore = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
    end
    return msp.apicore
end

msp.proto_logger = nil

function msp.enableProtoLog(on)
    if on and not proto_logger then
        proto_logger = protocol.getProtoLogger and protocol.getProtoLogger() or nil
        msp.proto_logger = proto_logger
    end
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

local delayDuration = 2
local delayStartTime = nil
local delayPending = false

function msp.wakeup()
    local session = rfsuite.session
    -- Optional protocol logging remains disabled by default.
    -- rfsuite.tasks.msp.enableProtoLog(true)

    if session.telemetrySensor == nil then return end

    if session.resetMSP and not delayPending then
        delayStartTime = os_clock()
        delayPending = true
        session.resetMSP = false
        utils.log("Delaying msp wakeup for " .. delayDuration .. " seconds", "info")
        return
    end

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

    if telemetryTypeChanged == true then
        msp.protocol = protocol.getProtocol()
        bindActiveTransport()
        applyProtocolQueueSettings()
        utils.session()
        msp.onConnectChecksInit = true
        telemetryTypeChanged = false
    end

    if session.telemetrySensor ~= nil and session.telemetryState == false then
        utils.session()
        msp.onConnectChecksInit = true
    end

    if session.telemetryState == true then
        mspQueue:processQueue()
    else
        mspQueue:clear()
    end
end

function msp.setTelemetryTypeChanged()
    telemetryTypeChanged = true
end

function msp.reset()
    mspQueue:clear()
    msp.activeProtocol = nil
    msp.onConnectChecksInit = true
    delayStartTime = nil
    delayPending = false
    local activeTransport = msp.protocol and msp.protocol.mspProtocol and msp.protocolTransports[msp.protocol.mspProtocol]
    if activeTransport and activeTransport.reset then activeTransport.reset() end
end

return msp
