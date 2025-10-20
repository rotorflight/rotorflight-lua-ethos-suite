--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local msp = {}

msp.activeProtocol = nil
msp.onConnectChecksInit = true

local protocol = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/protocols.lua"))()

local telemetryTypeChanged = false

msp.mspQueue = nil

msp.protocol = protocol.getProtocol()

msp.protocolTransports = {}
for i, v in pairs(protocol.getTransports()) do msp.protocolTransports[i] = assert(loadfile(v))() end

local transport = msp.protocolTransports[msp.protocol.mspProtocol]
msp.protocol.mspRead = transport.mspRead
msp.protocol.mspSend = transport.mspSend
msp.protocol.mspWrite = transport.mspWrite
msp.protocol.mspPoll = transport.mspPoll

msp.mspQueue = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/mspQueue.lua"))()
msp.mspQueue.maxRetries = msp.protocol.maxRetries
msp.mspQueue.loopInterval = 0.025
msp.mspQueue.copyOnAdd = true
msp.mspQueue.timeout = 2.0

msp.mspHelper = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/mspHelper.lua"))()
msp.api = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api.lua"))()
msp.common = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/common.lua"))()

local delayDuration = 2
local delayStartTime = nil
local delayPending = false

function msp.wakeup()

    if rfsuite.session.telemetrySensor == nil then return end

    if not msp.sensor then
        msp.sensor = sport.getSensor({primId = 0x32})
        msp.sensor:module(rfsuite.session.telemetrySensor:module())
    end

    if not msp.sensorTlm then
        msp.sensorTlm = sport.getSensor()
        msp.sensorTlm:module(rfsuite.session.telemetrySensor:module())
    end

    if rfsuite.session.resetMSP and not delayPending then
        delayStartTime = os.clock()
        delayPending = true
        rfsuite.session.resetMSP = false
        rfsuite.utils.log("Delaying msp wakeup for " .. delayDuration .. " seconds", "info")
        return
    end

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

    if telemetryTypeChanged == true then

        msp.protocol = protocol.getProtocol()

        local transport = msp.protocolTransports[msp.protocol.mspProtocol]
        msp.protocol.mspRead = transport.mspRead
        msp.protocol.mspSend = transport.mspSend
        msp.protocol.mspWrite = transport.mspWrite
        msp.protocol.mspPoll = transport.mspPoll

        rfsuite.utils.session()
        msp.onConnectChecksInit = true
        telemetryTypeChanged = false
    end

    if rfsuite.session.telemetrySensor ~= nil and rfsuite.session.telemetryState == false then
        rfsuite.utils.session()
        msp.onConnectChecksInit = true
    end

    local state

    if rfsuite.session.telemetrySensor then
        state = rfsuite.session.telemetryState
    else
        state = false
    end

    if state == true then

        msp.mspQueue:processQueue()

        if msp.onConnectChecksInit == true then if rfsuite.session.telemetrySensor then msp.sensor:module(rfsuite.session.telemetrySensor:module()) end end
    else
        msp.mspQueue:clear()
    end

end

function msp.setTelemetryTypeChanged() telemetryTypeChanged = true end

function msp.reset()
    rfsuite.tasks.msp.mspQueue:clear()
    msp.sensor = nil
    msp.activeProtocol = nil
    msp.onConnectChecksInit = true
    delayStartTime = nil
    msp.sensorTlm = nil
    delayPending = false
end

return msp
