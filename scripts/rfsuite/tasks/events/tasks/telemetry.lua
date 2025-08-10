--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--


local arg = { ... }
local config = arg[1]

local telemetry = {}

local lastEventTimes = {}
local lastValues     = {}
local lastAlertState = {}
local rollingSamples = {}

local userpref   = rfsuite.preferences
local eventPrefs = (userpref and userpref.events) or {}

-- Smartfuel retained as-is, already includes its own timing logic
local lastSmartfuelAnnounced = nil
local lastLowFuelAnnounced   = false
local lastLowFuelRepeat      = 0
local lastLowFuelRepeatCount = 0

local function smartfuelCallout(value)
    local smartfuelcallout = tonumber(eventPrefs.smartfuelcallout) or 0
    local thresholds = {}

    if smartfuelcallout == 0 then
        for _, i in ipairs({100, 10}) do table.insert(thresholds, i) end
    elseif smartfuelcallout == 10 then
        for i = 100, 10, -10 do table.insert(thresholds, i) end
    elseif smartfuelcallout == 20 then
        for i = 100, 20, -20 do table.insert(thresholds, i) end
    elseif smartfuelcallout == 25 then
        for i = 100, 25, -25 do table.insert(thresholds, i) end
    elseif smartfuelcallout == 50 then
        for _, i in ipairs({100, 50}) do table.insert(thresholds, i) end
    else
        table.insert(thresholds, smartfuelcallout)
    end

    -- Force 10% and 0% into the list
    table.insert(thresholds, 10)
    table.insert(thresholds, 0)

    -- Remove duplicates
    local seen = {}
    local unique = {}
    for _, v in ipairs(thresholds) do
        if not seen[v] then
            seen[v] = true
            table.insert(unique, v)
        end
    end

    -- Replace with deduped list
    thresholds = unique

    -- 0% logic (repeats, haptic)
    if value <= 0 then
        local now = os.clock() or os.clock()
        local repeats = tonumber(eventPrefs.smartfuelrepeats) or 1
        local haptic = eventPrefs.smartfuelhaptic and true or false

        if not lastLowFuelAnnounced then
            rfsuite.utils.playFile("status", "alerts/lowfuel.wav")
            if haptic then system.playHaptic(". . . .") end
            lastLowFuelRepeat = now
            lastLowFuelRepeatCount = 1
            lastLowFuelAnnounced = true
        elseif lastLowFuelRepeatCount < repeats and (now - lastLowFuelRepeat) >= 10 then
            rfsuite.utils.playFile("status", "alerts/lowfuel.wav")
            if haptic then system.playHaptic(". . . .") end
            lastLowFuelRepeat = now
            lastLowFuelRepeatCount = lastLowFuelRepeatCount + 1
        end
        return
    else
        lastLowFuelAnnounced = false
        lastLowFuelRepeat = 0
        lastLowFuelRepeatCount = 0
    end

    -- On first connect, announce the actual % value
    if lastSmartfuelAnnounced == nil then
        rfsuite.utils.playFile("status", "alerts/fuel.wav")
        system.playNumber(math.floor(value + 0.5), UNIT_PERCENT)
        lastSmartfuelAnnounced = math.floor(value + 0.5)
        return
    end

    local calloutValue = nil
    -- Find the largest threshold less than or equal to value and not previously called out
    for _, t in ipairs(thresholds) do
        if value <= t and lastSmartfuelAnnounced > t then
            calloutValue = t
            break
        end
    end

    if calloutValue then
        rfsuite.utils.playFile("status", "alerts/fuel.wav")
        system.playNumber(calloutValue, UNIT_PERCENT)
        lastSmartfuelAnnounced = calloutValue
    end
end


local function shouldAlert(key, interval)
    local now = os.clock() or os.clock()
    return (not lastAlertState[key]) or (now - (lastEventTimes[key] or 0)) >= interval
end

local function registerAlert(key, interval)
    lastEventTimes[key] = os.clock() or os.clock()
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

--[[
eventTable Configuration Options:

Each entry in eventTable supports the following optional fields:

- sensor     : (string) Name of the telemetry sensor to monitor.
- event      : (function) Function called with (value, interval, window) when sensor updates.
- interval   : (number) Minimum seconds between repeated alerts while condition persists.
               If omitted or 0, alert may trigger on every update.
- window     : (number) Number of recent samples to average before evaluating condition.
               Used to suppress alerts from momentary fluctuations. Default is 1 (no averaging).
- debounce   : (number) Minimum seconds between triggers based on value changes (non-threshold events).
               Used for sensors like profiles or modes to suppress rapid changes.

Only one of `interval` or `debounce` is typically used per entry.
]]

local eventTable = {
    {
        sensor = "armflags",
        event = function(value)
            local key = "armflags"
            if value == lastValues[key] then return end
            local armMap = {[0] = "disarmed.wav", [1] = "armed.wav", [2] = "disarmed.wav", [3] = "armed.wav"}
            local filename = armMap[math.floor(value)]
            if filename then
                rfsuite.utils.playFile("events", "alerts/" .. filename)
            end
        end
    },
    {
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

            local suppression = (userpref.general.gimbalsupression or 0.95) * 1024
            if math.abs(collective) > suppression or math.abs(aileron) > suppression or
               math.abs(elevator) > suppression or math.abs(rudder) > suppression then
                return
            end

            local key = "voltage"
            if avgVoltage < warnVoltage and shouldAlert(key, interval) then
                rfsuite.utils.playFile("events", "alerts/lowvoltage.wav")
                registerAlert(key, interval)
            elseif avgVoltage >= warnVoltage then
                lastAlertState[key] = false
            end
        end
    },
    {
        sensor = "temp_esc",
        interval = 10,
        window = 5,
        event = function(value, interval, window)
            if not eventPrefs.temp_esc then return end
            local escalertvalue = tonumber(eventPrefs.escalertvalue) or 90
            local avgTemp = updateRollingAverage("temp_esc", value, window)
            local key = "temp_esc"
            if avgTemp >= escalertvalue and shouldAlert(key, interval) then
                rfsuite.utils.playFile("events", "alerts/esctemp.wav")
                system.playHaptic(". . . .")
                registerAlert(key, interval)
            elseif avgTemp < escalertvalue then
                lastAlertState[key] = false
            end
        end
    },
    {
        sensor = "bec_voltage",
        interval = 10,
        window = 5,
        event = function(value, interval, window)
            if rfsuite.flightmode.current ~= "inflight" then
                lastAlertState["bec_voltage"] = false
                return
            end

            local batprefs = (rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery) or {}
            local alert_type     = tonumber(batprefs.alert_type or 0)
            local becalertvalue  = tonumber(batprefs.becalertvalue or 6.5)
            local rxalertvalue   = tonumber(batprefs.rxalertvalue or 7.4)
            local avgBEC         = updateRollingAverage("bec_voltage", value, window)
            local key            = "bec_voltage"

            if alert_type == 1 then
                if avgBEC < becalertvalue and shouldAlert(key, interval) then
                    rfsuite.utils.playFile("events", "alerts/becvolt.wav")
                    system.playHaptic(". . . .")
                    registerAlert(key, interval)
                elseif avgBEC >= becalertvalue then
                    lastAlertState[key] = false
                end
            elseif alert_type == 2 then
                if avgBEC < rxalertvalue and shouldAlert(key, interval) then
                    rfsuite.utils.playFile("events", "alerts/rxvolt.wav")
                    system.playHaptic(". . . .")
                    registerAlert(key, interval)
                elseif avgBEC >= rxalertvalue then
                    lastAlertState[key] = false
                end
            else
                lastAlertState[key] = false
            end
        end
    },
    {
        sensor = "smartfuel",
        event = function(value)
            smartfuelCallout(value)
        end
    },
    {
        sensor = "governor",
        event = function(value)
            local key = "governor"
            if value == lastValues[key] then return end
            if not rfsuite.session.isArmed or rfsuite.session.governorMode == 0 then return end
            local governorMap = {
                [0] = "off.wav", [1] = "idle.wav", [2] = "spoolup.wav", [3] = "recovery.wav",
                [4] = "active.wav", [5] = "thr-off.wav", [6] = "lost-hs.wav", [7] = "autorot.wav",
                [8] = "bailout.wav", [100] = "disabled.wav", [101] = "disarmed.wav"
            }
            local filename = governorMap[math.floor(value)]
            if filename then rfsuite.utils.playFile("events", "gov/" .. filename) end
        end
    },
    {
        sensor = "pid_profile",
        debounce = 0.25,
        event = function(value)
            local key = "pid_profile"
            if value == lastValues[key] then return end
            rfsuite.utils.playFile("events", "alerts/profile.wav")
            system.playNumber(math.floor(value))
        end
    },
    {
        sensor = "rate_profile",
        debounce = 0.25,
        event = function(value)
            local key = "rate_profile"
            if value == lastValues[key] then return end
            rfsuite.utils.playFile("events", "alerts/rates.wav")
            system.playNumber(math.floor(value))
        end
    }
}

function telemetry.wakeup()
    local now = os.clock()
    for _, item in ipairs(eventTable) do
        local key = item.sensor
        local interval = item.interval or 0
        local debounce = item.debounce or 0
        local lastTime = lastEventTimes[key] or (now - interval)
        local lastVal = lastValues[key]

        if not eventPrefs[key] then goto continue end

        local source = rfsuite.tasks.telemetry.getSensorSource(key)
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
    lastValues     = {}
    lastAlertState = {}
    rollingSamples = {}
end

return telemetry
