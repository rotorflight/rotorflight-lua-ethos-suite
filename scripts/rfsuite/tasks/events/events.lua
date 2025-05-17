--[[

 * Copyright (C) Rotorflight Project
 *
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
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 
]] --
local arg = {...}
local config = arg[1]

local events = {}

local lastEventTimes = {}
local lastValues = {}

local userpref = rfsuite.preferences

local telemetryStartTime = nil

local eventTable = {
    telemetry = {
        {
            sensor = "armflags",
            event = function(value)
                local armMap = {[0] = "disarmed.wav", [1] = "armed.wav", [2] = "disarmed.wav", [3] = "armed.wav"}
                rfsuite.utils.playFile("events", "alerts/" .. armMap[math.floor(value)])
                if value == 1 or value == 3 then
                    rfsuite.session.isArmed = true
                else
                    rfsuite.session.isArmed = false    
                end
            end,
            interval = nil
        },
        {
            sensor = "voltage",
            event = function(value)
                local session = rfsuite.session
                if session.batteryConfig then
                    if session.batteryConfig.batteryCellCount and session.batteryConfig.vbatwarningcellvoltage and session.batteryConfig.vbatmincellvoltage then
                        local cellVoltage = value / session.batteryConfig.batteryCellCount
                        local suppressThreshold = session.batteryConfig.vbatmincellvoltage / 2

                        -- Only proceed if cellVoltage is either zero or above the suppression threshold
                        if cellVoltage >= 0 and cellVoltage < suppressThreshold then
                            -- Suppress alert
                            return
                        end

                        if cellVoltage < session.batteryConfig.vbatwarningcellvoltage then
                            rfsuite.utils.playFile("events", "alerts/lowvoltage.wav")
                        end
                    end
                end
            end,
            interval = 10
        },
        {
            sensor = "fuel",
            event = function(value)
                local session = rfsuite.session
                if session.batteryConfig then
                    if session.batteryConfig.consumptionWarningPercentage then
                        if value < session.batteryConfig.consumptionWarningPercentage then
                            rfsuite.utils.playFile("events", "alerts/lowfuel.wav")
                        end
                    end
                end
            end,
            interval = 10
        },
        {
            sensor = "governor",
            event = function(value)
                if rfsuite.session.isArmed == false or rfsuite.session.governorMode == 0 then
                    return
                end
                local governorMap = {[0] = "off.wav", [1] = "idle.wav", [2] = "spoolup.wav", [3] = "recovery.wav", [4] = "active.wav", [5] = "thr-off.wav", [6] = "lost-hs.wav", [7] = "autorot.wav", [8] = "bailout.wav", [100] = "disabled.wav", [101] = "disarmed.wav"}
                rfsuite.utils.playFile("events", "gov/" .. governorMap[math.floor(value)])
            end,
            interval = nil
        },
        {
            sensor = "pid_profile",
            event = function(value)
                rfsuite.utils.playFile("events", "alerts/profile.wav")
                system.playNumber(math.floor(value))
            end,
            interval = nil,
            debounce = 0.25               
        },
        {
            sensor = "rate_profile",
            event = function(value)
                rfsuite.utils.playFile("events", "alerts/rates.wav")
                system.playNumber(math.floor(value))
            end,
            interval = nil,
            debounce = 0.25          
        },
        {
            sensor = "adj_f",
            event = function(value) end,
        },
        {
            sensor = "adj_v",
            event = function(value) end,
        }
    }
}

function events.wakeup()
    local currentTime = os.clock()

    if rfsuite.session.isConnected and rfsuite.session.telemetryState then
        if telemetryStartTime == nil then
            telemetryStartTime = currentTime
        end

        -- Wait 2.5 seconds after telemetry becomes active
        if (currentTime - telemetryStartTime) < 2.5 then
            return
        end

        -- Handle telemetry events
        for _, item in ipairs(eventTable.telemetry) do
            local key = item.sensor
            local data = item
            local sensor = rfsuite.tasks.telemetry.getSensorSource(key)

            if sensor then
                local value = sensor:value()

                if value ~= nil then
                    local lastValue = lastValues[key]
                    if lastValue ~= nil and value == lastValue then
                        goto continue
                    end

                    local debounce = data.debounce or 0
                    local lastTime = lastEventTimes[key] or 0
                    if debounce > 0 and (currentTime - lastTime) < debounce then
                        goto continue
                    end

                    if data.interval and (currentTime - lastTime) < data.interval then
                        goto continue
                    end

                    if not rfsuite.preferences or not rfsuite.preferences.announcements or rfsuite.preferences.announcements[key] ~= true then
                        goto continue
                    end

                    data.event(value)
                    lastEventTimes[key] = currentTime
                    lastValues[key] = value
                end
                ::continue::
            end
        end
    else
        telemetryStartTime = nil  -- Reset when telemetry disconnects
    end
end


-- allow events table to be called from other modules
events.eventTable = eventTable

return events
