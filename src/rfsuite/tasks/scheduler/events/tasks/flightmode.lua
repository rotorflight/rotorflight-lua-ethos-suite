--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local flightmode = {}
local lastFlightMode = nil
local hasBeenInFlight = false
local lastArmed = false

local throttleThreshold = 35

local function isGovernorActive(value) return type(value) == "number" and value >= 4 and value <= 8 end

function flightmode.inFlight()
    local telemetry = rfsuite.tasks.telemetry

    if not telemetry.active() or not rfsuite.session.isArmed then return false end

    local governor = telemetry.getSensor("governor")
    if isGovernorActive(governor) then return true end

    local rx = rfsuite.session.rx
    local throttle = rx and rx.values and rx.values.throttle

    if throttle and throttle > throttleThreshold then return true end

    return false
end

function flightmode.reset()
    lastFlightMode = nil
    hasBeenInFlight = false
end

local function determineMode()
    local armed = rfsuite.session.isArmed
    local connected = rfsuite.session.isConnected
    local current = rfsuite.flightmode.current

    if current == "inflight" and not connected then
        hasBeenInFlight = false
        lastArmed = armed
        return "postflight"
    end

    if armed and not lastArmed then
        hasBeenInFlight = false
        lastArmed = armed
        return "preflight"
    end

    if flightmode.inFlight() then
        hasBeenInFlight = true
        lastArmed = armed
        return "inflight"
    end

    lastArmed = armed
    return hasBeenInFlight and "postflight" or "preflight"
end

function flightmode.wakeup()
    local mode = determineMode()

    if lastFlightMode ~= mode then
        rfsuite.utils.log("Flight mode: " .. mode, "info")
        rfsuite.flightmode.current = mode
        lastFlightMode = mode
    end
end

return flightmode
