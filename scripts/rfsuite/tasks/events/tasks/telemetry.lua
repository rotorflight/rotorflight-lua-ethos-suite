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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local arg = { ... }
local config = arg[1]

local telemetry = {}

local lastEventTimes = {}
local lastValues     = {}
local lastAlertState  = {}

local userpref       = rfsuite.preferences
local eventPrefs     = (userpref and userpref.events) or {}

-- Alert State for Smartfuel
local lastSmartfuelAnnounced = nil
local lastLowFuelAnnounced   = false
local lastLowFuelRepeat      = 0
local lastLowFuelRepeatCount = 0

local function smartfuelCallout(value)
    local smartfuelcallout = tonumber(eventPrefs.smartfuelcallout) or 0

    -- Set up thresholds for smartfuelcallout > 0
    local thresholds = {}
    if smartfuelcallout == 10 then
        for i = 100, 10, -10 do table.insert(thresholds, i) end
    elseif smartfuelcallout == 25 then
        for i = 100, 25, -25 do table.insert(thresholds, i) end
    elseif smartfuelcallout == 50 then
        for _, i in ipairs({100, 50}) do table.insert(thresholds, i) end
    elseif smartfuelcallout == 20 then
        for _, i in ipairs({100, 75, 50, 25, 20}) do table.insert(thresholds, i) end
    else
        table.insert(thresholds, smartfuelcallout)
    end

    -- Universal: handle 0% callouts and repeats (for ALL alerting modes)
    if value <= 0 then
        local now = rfsuite.clock or os.clock()
        local repeats = tonumber(eventPrefs.smartfuelrepeats) or 1
        local haptic = eventPrefs.smartfuelhaptic and true or false

        if not lastLowFuelAnnounced then
            -- Play one initial alert
            rfsuite.utils.playFile("status", "alerts/lowfuel.wav")
            if haptic then system.playHaptic(". . . .") end
            lastLowFuelRepeat      = now
            lastLowFuelRepeatCount = 1
            lastLowFuelAnnounced   = true
        elseif lastLowFuelRepeatCount < repeats and (now - (lastLowFuelRepeat or 0)) >= 10 then
            -- Play repeats, 10s apart
            rfsuite.utils.playFile("status", "alerts/lowfuel.wav")
            if haptic then system.playHaptic(". . . .") end
            lastLowFuelRepeat      = now
            lastLowFuelRepeatCount = lastLowFuelRepeatCount + 1
        end
        return
    else
        lastLowFuelAnnounced   = false
        lastLowFuelRepeat      = 0
        lastLowFuelRepeatCount = 0
    end

    -- For OFF mode (smartfuelcallout==0), also play once at 10%
    if smartfuelcallout == 0 then
        if value <= 10 and not lastSmartfuelAnnounced then
            rfsuite.utils.playFile("status", "alerts/lowfuel.wav")
            lastSmartfuelAnnounced = true
        end
        if value > 10 then
            lastSmartfuelAnnounced = false
        end
        return
    end

    -- Normal callout for other modes
    local calloutValue = nil
    for _, t in ipairs(thresholds) do
        if value <= t and (not lastSmartfuelAnnounced or lastSmartfuelAnnounced > t) then
            calloutValue = t
            break
        end
    end

    if calloutValue then
        rfsuite.utils.playFile("status", "alerts/fuel.wav")
        system.playNumber(calloutValue, UNIT_PERCENT)
        lastSmartfuelAnnounced = calloutValue
    end

    if value > (thresholds[1] or 100) then
        lastSmartfuelAnnounced = nil
    end
end

----------------------------------------------------------------------

local eventTable = {
    {
        sensor = "armflags",
        event = function(value)
            local armMap = {
                [0] = "disarmed.wav",
                [1] = "armed.wav",
                [2] = "disarmed.wav",
                [3] = "armed.wav",
            }
            local filename = armMap[math.floor(value)]
            if filename then
                rfsuite.utils.playFile("events", "alerts/" .. filename)
            end
        end,
    },
    {
        sensor = "voltage",
        event = function(value)
            local session = rfsuite.session
            if not session.batteryConfig then return end

            local cellCount   = session.batteryConfig.batteryCellCount
            local warnVoltage = session.batteryConfig.vbatwarningcellvoltage
            local minVoltage  = session.batteryConfig.vbatmincellvoltage

            local collective = session.rx.values['collective'] or 0
            local aileron    = session.rx.values['aileron'] or 0
            local elevator   = session.rx.values['elevator'] or 0
            local rudder     = session.rx.values['rudder'] or 0

            if not (cellCount and warnVoltage and minVoltage) then return end

            local cellVoltage = value / cellCount
            if cellVoltage >= 0 and cellVoltage < (minVoltage / 2) then return end

            local suppressionPercent = userpref.general.gimbalsupression or 0.85
            local suppressionLimit = suppressionPercent * 1024

            if math.abs(collective) > suppressionLimit or
               math.abs(aileron) > suppressionLimit or
               math.abs(elevator) > suppressionLimit or
               math.abs(rudder) > suppressionLimit then
                return
            end

            if cellVoltage < warnVoltage then
                rfsuite.utils.playFile("events", "alerts/lowvoltage.wav")
            end
        end,
        interval = 10
    },
    {
        sensor = "governor",
        event = function(value)
            if not rfsuite.session.isArmed or rfsuite.session.governorMode == 0 then return end

            local governorMap = {
                [0] = "off.wav", [1] = "idle.wav", [2] = "spoolup.wav",
                [3] = "recovery.wav", [4] = "active.wav", [5] = "thr-off.wav",
                [6] = "lost-hs.wav", [7] = "autorot.wav", [8] = "bailout.wav",
                [100] = "disabled.wav", [101] = "disarmed.wav"
            }
            local filename = governorMap[math.floor(value)]
            if filename then
                rfsuite.utils.playFile("events", "gov/" .. filename)
            end
        end
    },
    {
        sensor = "pid_profile",
        event = function(value)
            rfsuite.utils.playFile("events", "alerts/profile.wav")
            system.playNumber(math.floor(value))
        end,
        debounce = 0.25
    },
    {
        sensor = "rate_profile",
        event = function(value)
            rfsuite.utils.playFile("events", "alerts/rates.wav")
            system.playNumber(math.floor(value))
        end,
        debounce = 0.25
    },
    {
        sensor = "temp_esc",
        event = function(value)
            if not eventPrefs.temp_esc then return end
            local escalertvalue = tonumber(eventPrefs.escalertvalue) or 90
            local key = "temp_esc"
            local now = rfsuite.clock or os.clock()

            if value >= escalertvalue then
                if not lastAlertState[key] or (now - (lastEventTimes[key] or 0)) >= 10 then
                    rfsuite.utils.playFile("events", "alerts/esctemp.wav")
                    system.playHaptic(". . . .")
                    lastEventTimes[key] = now
                    lastAlertState[key] = true
                end
            else
                lastAlertState[key] = false
            end
        end,
        interval = 10,
    },
    {
        sensor = "bec_voltage",
        event = function(value)
            if not eventPrefs.bec_voltage then return end
            if rfsuite.flightmode.current ~= "inflight" then
                lastAlertState["bec_voltage"] = false
                return
            end
            local becalertvalue = tonumber(eventPrefs.becalertvalue) or 6.5
            local key = "bec_voltage"
            local now = rfsuite.clock or os.clock()

            if value < becalertvalue then
                if not lastAlertState[key] or (now - (lastEventTimes[key] or 0)) >= 10 then
                    rfsuite.utils.playFile("events", "alerts/becvolt.wav")
                    system.playHaptic(". . . .")
                    lastEventTimes[key] = now
                    lastAlertState[key] = true
                end
            else
                lastAlertState[key] = false
            end
        end,
        interval = 10,
    },
    {
        sensor = "smartfuel",
        event = function(value)
            smartfuelCallout(value)
        end,
        interval = 10,
    },
}

----------------------------------------------------------------------

function telemetry.wakeup()
    local now = rfsuite.clock
    for _, item in ipairs(eventTable) do
        local key = item.sensor
        local interval = item.interval or 0
        local debounce = item.debounce or 0
        local lastTime = lastEventTimes[key] or 0
        local lastVal = lastValues[key]

        -- Events check
        local enabled = eventPrefs[key]
        if not eventPrefs[key] then
            goto continue
        end

        local source = rfsuite.tasks.telemetry.getSensorSource(key)
        if not source then goto continue end
        local value = source:value()
        if value == nil then goto continue end

        -- For interval-based repeating alerts, always run
        if interval > 0 and (now - lastTime) >= interval then
            item.event(value)
            lastEventTimes[key] = now
        elseif interval == 0 and (not lastVal or value ~= lastVal) and (now - lastTime) >= debounce then
            item.event(value)
            lastEventTimes[key] = now
        else
        end
        lastValues[key] = value
        ::continue::
    end
end

telemetry.eventTable = eventTable

return telemetry
