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

-- Tracking tables for event timing and value changes
local lastEventTimes = {}
local lastValues     = {}
local lastPlayTime   = {}

-- Shortcut to user preferences
local userpref = rfsuite.preferences

-- Definition of telemetry-driven events
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
        interval = nil,
        debounce = nil,
    },
    {
        sensor = "voltage",
        event = function(value)
            local session = rfsuite.session
            if not session.batteryConfig then
                return
            end

            local cellCount    = session.batteryConfig.batteryCellCount
            local warnVoltage  = session.batteryConfig.vbatwarningcellvoltage
            local minVoltage   = session.batteryConfig.vbatmincellvoltage

            local collective = session.rx.values['collective'] or 0
            local aileron = session.rx.values['aileron'] or 0
            local elevator = session.rx.values['elevator'] or 0
            local rudder = session.rx.values['rudder'] or 0

            if not (cellCount and warnVoltage and minVoltage) then
                return
            end

            local cellVoltage      = value / cellCount
            local suppressThreshold = minVoltage / 2

            -- Suppress if below suppression threshold but not zero
            if cellVoltage >= 0 and cellVoltage < suppressThreshold then
                return
            end

            -- Define suppression percentage threshold (e.g., 0.8 for 80%)
            local suppressionPercent = rfsuite.preferences.general.gimbalsupression or 0.85
            local maxStickValue = 1024
            local suppressionLimit = suppressionPercent * maxStickValue

            -- Suppress if any stick input exceeds the suppression limit
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
        interval = 10,
        debounce = nil,
    },
    {
        sensor = "fuel",
        event = function(value)
            local session = rfsuite.session
            if not (session.batteryConfig and session.batteryConfig.consumptionWarningPercentage) then
                return
            end

            local warningPct = session.batteryConfig.consumptionWarningPercentage
            if value < warningPct then
                rfsuite.utils.playFile("events", "alerts/lowfuel.wav")
            end
        end,
        interval = 10,
        debounce = nil,
    },
    {
        sensor = "governor",
        event = function(value)
            if not rfsuite.session.isArmed or rfsuite.session.governorMode == 0 then
                return
            end

            local governorMap = {
                [0]   = "off.wav",
                [1]   = "idle.wav",
                [2]   = "spoolup.wav",
                [3]   = "recovery.wav",
                [4]   = "active.wav",
                [5]   = "thr-off.wav",
                [6]   = "lost-hs.wav",
                [7]   = "autorot.wav",
                [8]   = "bailout.wav",
                [100] = "disabled.wav",
                [101] = "disarmed.wav",
            }
            local filename = governorMap[math.floor(value)]
            if filename then
                rfsuite.utils.playFile("events", "gov/" .. filename)
            end
        end,
        interval = nil,
        debounce = nil,
    },
    {
        sensor = "pid_profile",
        event = function(value)
            rfsuite.utils.playFile("events", "alerts/profile.wav")
            system.playNumber(math.floor(value))
        end,
        interval = nil,
        debounce = 0.25,
    },
    {
        sensor = "rate_profile",
        event = function(value)
            rfsuite.utils.playFile("events", "alerts/rates.wav")
            system.playNumber(math.floor(value))
        end,
        interval = nil,
        debounce = 0.25,
    },
    {
        sensor = "adj_f",
        event = function(value)
            -- Placeholder for future implementation
        end,
        interval = nil,
        debounce = nil,
    },
    {
        sensor = "adj_v",
        event = function(value)
            -- Placeholder for future implementation
        end,
        interval = nil,
        debounce = nil,
    },
}

--------------------------------------------------------------------------------
-- Handles telemetry wakeup events by processing each telemetry item in eventTable.
--
-- For each configured event:
--   • Retrieves the sensor source and its current value.
--   • Skips if the value hasn't changed since last event.
--   • Applies debounce and interval checks to avoid rapid/redundant firing.
--   • Checks user preferences to see if the event is enabled.
--   • If conditions are met, triggers the event callback and updates timing/value.
--------------------------------------------------------------------------------
function telemetry.wakeup()
    local currentTime = rfsuite.clock

    for _, item in ipairs(eventTable) do
        local key      = item.sensor
        local callback = item.event
        local interval = item.interval or 0
        local debounce = item.debounce or 0

        local sensor = rfsuite.tasks.telemetry.getSensorSource(key)
        if not sensor then
            goto continue
        end

        local value = sensor:value()
        if value == nil then
            goto continue
        end

        local lastValue = lastValues[key]
        if lastValue ~= nil and value == lastValue then
            goto continue
        end

        local lastTime = lastEventTimes[key] or 0
        if debounce > 0 and (currentTime - lastTime) < debounce then
            goto continue
        end

        if interval > 0 and (currentTime - lastTime) < interval then
            goto continue
        end

        if not userpref or not userpref.events or userpref.events[key] ~= true then
            goto continue
        end

        -- Trigger event and update trackers
        callback(value)
        lastEventTimes[key] = currentTime
        lastValues[key]     = value

        ::continue::
    end
end

-- Expose eventTable for other modules if needed
telemetry.eventTable = eventTable

return telemetry
