--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local MSP_PROTOCOL_VERSION = rfsuite.config.mspProtocolVersion or 1

local arg = {...}
local config = arg[1]

local msp = {}

msp.activeProtocol = nil      -- Current telemetry protocol type in use
msp.onConnectChecksInit = true -- Flag to run initial checks on telemetry connect

local protocol = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/protocols.lua"))()

local telemetryTypeChanged = false -- Set when switching CRSF/S.Port/etc.

msp.mspQueue = nil

-- Protocol parameters for current telemetry type
msp.protocol = protocol.getProtocol()

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
msp.mspQueue = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/mspQueue.lua"))()
msp.mspQueue.maxRetries   = msp.protocol.maxRetries
msp.mspQueue.loopInterval = 0.031            -- Queue processing rate
msp.mspQueue.copyOnAdd    = true             -- Clone messages on enqueue
msp.mspQueue.timeout      = msp.protocol.mspQueueTimeout or 2.0

-- Load helpers and API handlers
msp.mspHelper = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/mspHelper.lua"))()
msp.api       = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api.lua"))()
msp.common    = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/common.lua"))()
msp.common.setProtocolVersion(MSP_PROTOCOL_VERSION or 1)

-- Delay handling for clean protocol reset
local delayDuration  = 2
local delayStartTime = nil
local delayPending   = false

-- Main MSP poll loop (called by script wakeups)
function msp.wakeup()

    -- Nothing to do if no telemetry sensor
    if rfsuite.session.telemetrySensor == nil then return end

    -- Apply delay after reset request
    if rfsuite.session.resetMSP and not delayPending then
        delayStartTime = os.clock()
        delayPending = true
        rfsuite.session.resetMSP = false
        rfsuite.utils.log("Delaying msp wakeup for " .. delayDuration .. " seconds", "info")
        return
    end

    -- Hold off processing while in delay period
    if delayPending then
        if os.clock() - delayStartTime >= delayDuration then
            rfsuite.utils.log("Delay complete; resuming msp wakeup", "info")
            delayPending = false
        else
            rfsuite.tasks.msp.mspQueue:clear()
            return
        end
    end

    msp.activeProtocol = rfsuite.session.telemetryType

    -- Telemetry type changed (e.g., CRSF <-> S.Port)
    if telemetryTypeChanged == true then

        msp.protocol = protocol.getProtocol()

        local transport = msp.protocolTransports[msp.protocol.mspProtocol]
        msp.protocol.mspRead  = transport.mspRead
        msp.protocol.mspSend  = transport.mspSend
        msp.protocol.mspWrite = transport.mspWrite
        msp.protocol.mspPoll  = transport.mspPoll

        rfsuite.utils.session()
        msp.onConnectChecksInit = true
        telemetryTypeChanged = false
    end

    -- If telemetry was disconnected, re-run init handlers
    if rfsuite.session.telemetrySensor ~= nil and rfsuite.session.telemetryState == false then
        rfsuite.utils.session()
        msp.onConnectChecksInit = true
    end

    -- Determine telemetry connection state
    local state
    if rfsuite.session.telemetrySensor then
        state = rfsuite.session.telemetryState
    else
        state = false
    end

    -- Run queue when connected, otherwise clear it
    if state == true then
        msp.mspQueue:processQueue()
    else
        msp.mspQueue:clear()
    end
end

-- Mark that protocol should be reloaded on next wakeup
function msp.setTelemetryTypeChanged()
    telemetryTypeChanged = true
end

-- Reset MSP state and transport
function msp.reset()
    rfsuite.tasks.msp.mspQueue:clear()
    msp.activeProtocol = nil
    msp.onConnectChecksInit = true
    delayStartTime = nil
    delayPending = false
    if transport and transport.reset then transport.reset() end
end

return msp