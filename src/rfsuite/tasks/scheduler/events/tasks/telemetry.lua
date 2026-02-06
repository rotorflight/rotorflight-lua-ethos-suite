--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local telemetry = {}

local lastEventTimes = {}
local lastValues = {}
local lastAlertState = {}
local rollingSamples = {}
local sensorSources = {}

local lastSmartfuelAnnounced = nil
local lastLowFuelAnnounced = false
local lastLowFuelRepeat = 0
local lastLowFuelRepeatCount = 0

local utils = rfsuite.utils
local os_clock = os.clock
local math_floor = math.floor
local math_abs = math.abs
local system_playNumber = system.playNumber
local system_playHaptic = system.playHaptic

local lastSmartfuelSel = nil
local cachedSmartfuelThresholds = nil

local function buildSmartfuelThresholds(sel)
    if sel == lastSmartfuelSel and cachedSmartfuelThresholds then return cachedSmartfuelThresholds end

    local t
    if sel == 0 then
        t = {100, 10}
    elseif sel == 10 then
        t = {}
        for i = 100, 10, -10 do t[#t + 1] = i end
    elseif sel == 20 then
        t = {}
        for i = 100, 20, -20 do t[#t + 1] = i end
        t[#t + 1] = 10
    elseif sel == 25 then
        t = {100, 75, 50, 25, 10}
    elseif sel == 50 then
        t = {100, 50, 10}
    elseif sel == 5 then
        t = {50, 5}
    elseif type(sel) == "number" and sel > 0 then
        t = {sel}
    else
        t = {10}
    end
    lastSmartfuelSel = sel
    cachedSmartfuelThresholds = t
    return t
end

local function smartfuelCallout(value)
    local eventPrefs = rfsuite.preferences.events or {}
    local smartfuelcallout = tonumber(eventPrefs.smartfuelcallout) or 0
    local thresholds = buildSmartfuelThresholds(smartfuelcallout)

    if value <= 0 then
        local now = os_clock()
        local repeats = tonumber(eventPrefs.smartfuelrepeats) or 1
        local haptic = eventPrefs.smartfuelhaptic and true or false

        if not lastLowFuelAnnounced then
            utils.playFile("status", "alerts/lowfuel.wav")
            if haptic then system_playHaptic(". . . .") end
            lastLowFuelRepeat = now
            lastLowFuelRepeatCount = 1
            lastLowFuelAnnounced = true
        elseif lastLowFuelRepeatCount < repeats and (now - lastLowFuelRepeat) >= 10 then
            utils.playFile("status", "alerts/lowfuel.wav")
            if haptic then system_playHaptic(". . . .") end
            lastLowFuelRepeat = now
            lastLowFuelRepeatCount = lastLowFuelRepeatCount + 1
        end
        return
    else
        lastLowFuelAnnounced = false
        lastLowFuelRepeat = 0
        lastLowFuelRepeatCount = 0
    end

    if lastSmartfuelAnnounced == nil then
        utils.playFile("status", "alerts/fuel.wav")
        system_playNumber(math_floor(value + 0.5), UNIT_PERCENT)
        lastSmartfuelAnnounced = math_floor(value + 0.5)
        return
    end

    local calloutValue = nil

    for _, t in ipairs(thresholds) do
        if value <= t and lastSmartfuelAnnounced > t then
            calloutValue = t
            break
        end
    end

    if calloutValue then
        utils.playFile("status", "alerts/fuel.wav")
        system_playNumber(calloutValue, UNIT_PERCENT)
        lastSmartfuelAnnounced = calloutValue
    end
end

local function shouldAlert(key, interval)
    local now = os_clock()
    return (not lastAlertState[key]) or (now - (lastEventTimes[key] or 0)) >= interval
end

local function registerAlert(key, interval)
    lastEventTimes[key] = os_clock()
    lastAlertState[key] = true
end

local function updateRollingAverage(key, newValue, window)
    rollingSamples[key] = rollingSamples[key] or {}
    local samples = rollingSamples[key]
    table.insert(samples, newValue)
    if #samples > window then table.remove(samples, 1) end
    local sum = 0
    for _, v in ipairs(samples) do sum = sum + v end
    return sum / #samples
end

local eventTable = {
    {
        sensor = "armflags",
        event = function(value)
            local key = "armflags"
            if value == lastValues[key] then return end
            local armMap = {[0] = "disarmed.wav", [1] = "armed.wav", [2] = "disarmed.wav", [3] = "armed.wav"}
            local filename = armMap[math_floor(value)]
            if filename then utils.playFile("events", "alerts/" .. filename) end
        end
    }, {
        sensor = "voltage",
        interval = 10,
        window = 5,
        event = function(value, interval, window)
            local session = rfsuite.session
            if not session.batteryConfig then return end

            local cellCount = session.batteryConfig.batteryCellCount
            local warnVoltage = session.batteryConfig.vbatwarningcellvoltage
            local minVoltage = session.batteryConfig.vbatmincellvoltage

            local cellVoltage = value / cellCount
            if cellVoltage < (minVoltage / 2) then return end

            local avgVoltage = updateRollingAverage("voltage", cellVoltage, window)

            local collective = session.rx.values['collective'] or 0
            local aileron = session.rx.values['aileron'] or 0
            local elevator = session.rx.values['elevator'] or 0
            local rudder = session.rx.values['rudder'] or 0

            local suppression = (rfsuite.preferences.general.gimbalsupression or 0.95) * 1024
            if math_abs(collective) > suppression or math_abs(aileron) > suppression or math_abs(elevator) > suppression or math_abs(rudder) > suppression then return end

            local key = "voltage"
            if avgVoltage < warnVoltage and shouldAlert(key, interval) then
                utils.playFile("events", "alerts/lowvoltage.wav")
                registerAlert(key, interval)
            elseif avgVoltage >= warnVoltage then
                lastAlertState[key] = false
            end
        end
    }, {
        sensor = "temp_esc",
        interval = 10,
        window = 5,
        event = function(value, interval, window)
            local eventPrefs = rfsuite.preferences.events or {}
            if not eventPrefs.temp_esc then return end
            local escalertvalue = tonumber(eventPrefs.escalertvalue) or 90
            local avgTemp = updateRollingAverage("temp_esc", value, window)
            local key = "temp_esc"
            if avgTemp >= escalertvalue and shouldAlert(key, interval) then
                utils.playFile("events", "alerts/esctemp.wav")
                system_playHaptic(". . . .")
                registerAlert(key, interval)
            elseif avgTemp < escalertvalue then
                lastAlertState[key] = false
            end
        end
    }, {
        sensor = "bec_voltage",
        interval = 10,
        window = 5,
        event = function(value, interval, window)
            if rfsuite.flightmode.current ~= "inflight" then
                lastAlertState["bec_voltage"] = false
                return
            end

            local session = rfsuite.session
            local batprefs = (session.modelPreferences and session.modelPreferences.battery) or {}
            local alert_type = tonumber(batprefs.alert_type or 0)
            local becalertvalue = tonumber(batprefs.becalertvalue or 6.5)
            local rxalertvalue = tonumber(batprefs.rxalertvalue or 7.4)
            local avgBEC = updateRollingAverage("bec_voltage", value, window)
            local key = "bec_voltage"

            if alert_type == 1 then
                if avgBEC < becalertvalue and shouldAlert(key, interval) then
                    utils.playFile("events", "alerts/becvolt.wav")
                    system_playHaptic(". . . .")
                    registerAlert(key, interval)
                elseif avgBEC >= becalertvalue then
                    lastAlertState[key] = false
                end
            elseif alert_type == 2 then
                if avgBEC < rxalertvalue and shouldAlert(key, interval) then
                    utils.playFile("events", "alerts/rxvolt.wav")
                    system_playHaptic(". . . .")
                    registerAlert(key, interval)
                elseif avgBEC >= rxalertvalue then
                    lastAlertState[key] = false
                end
            else
                lastAlertState[key] = false
            end
        end
    }, {sensor = "smartfuel", event = function(value) smartfuelCallout(value) end}, {
        sensor = "governor",
        event = function(value)
            local key = "governor"
            if value == lastValues[key] then return end
            local session = rfsuite.session
            if not session.isArmed or session.governorMode == 0 then return end
            local governorMap = {[0] = "off.wav", [1] = "idle.wav", [2] = "spoolup.wav", [3] = "recovery.wav", [4] = "active.wav", [5] = "thr-off.wav", [6] = "lost-hs.wav", [7] = "autorot.wav", [8] = "bailout.wav", [100] = "disabled.wav", [101] = "disarmed.wav"}
            local filename = governorMap[math_floor(value)]
            if filename then utils.playFile("events", "gov/" .. filename) end
        end
    }, {
        sensor = "pid_profile",
        debounce = 0.25,
        event = function(value)
            local key = "pid_profile"
            if value == lastValues[key] then return end
            utils.playFile("events", "alerts/profile.wav")
            system_playNumber(math_floor(value))
        end
    }, {
        sensor = "rate_profile",
        debounce = 0.25,
        event = function(value)
            local key = "rate_profile"
            if value == lastValues[key] then return end
            utils.playFile("events", "alerts/rates.wav")
            system_playNumber(math_floor(value))
        end
    }
}

function telemetry.wakeup()

    -- we need governor mode for some events
    if rfsuite.session.governorMode == nil then
        if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then
            rfsuite.tasks.msp.helpers.governorMode(function(governorMode)
                utils.log("Telemetry event Received governor mode: " .. tostring(governorMode), "info")
            end)
        end
    end

    local now = os_clock()
    local eventPrefs = rfsuite.preferences.events or {}
    local tlmTask = rfsuite.tasks.telemetry

    for _, item in ipairs(eventTable) do
        local key = item.sensor
        local interval = item.interval or 0
        local debounce = item.debounce or 0
        local lastTime = lastEventTimes[key] or (now - interval)
        local lastVal = lastValues[key]

        if not eventPrefs[key] then goto continue end

        local source = sensorSources[key]
        if not source then
            if tlmTask then
                source = tlmTask.getSensorSource(key)
                if source then sensorSources[key] = source end
            end
        end
        if not source then goto continue end

        local value = source:value()
        if value == nil then goto continue end

        if interval > 0 then
            item.event(value, interval, item.window or 1)
        elseif (not lastVal or value ~= lastVal) or debounce == 0 or (now - lastTime) >= debounce then
            item.event(value, interval, item.window or 1)
            lastEventTimes[key] = now
        end

        lastValues[key] = value
        ::continue::
    end
end

telemetry.eventTable = eventTable

function telemetry.reset()
    lastSmartfuelAnnounced = nil
    lastLowFuelAnnounced = false
    lastLowFuelRepeat = 0
    lastLowFuelRepeatCount = 0
    lastEventTimes = {}
    lastValues = {}
    lastAlertState = {}
    rollingSamples = {}
    sensorSources = {}
end

return telemetry
