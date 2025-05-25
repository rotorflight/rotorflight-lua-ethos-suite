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

-- Tables to store last play times and previous states
local lastPlayTime = lastPlayTime or {}
local lastSwitchState = lastSwitchState or {}

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
    },
    switches = {},
    units = {},

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

                    if not rfsuite.preferences or not rfsuite.preferences.events or rfsuite.preferences.events[key] ~= true then
                        goto continue
                    end

                    data.event(value)
                    lastEventTimes[key] = currentTime
                    lastValues[key] = value
                end
                ::continue::
            end
        end

        -- populate switches -- we do this only if the table is empty (means we can reset if switches are changed)
        if next(eventTable.switches) == nil and rfsuite.preferences.switches then
            for key, v in pairs(rfsuite.preferences.switches) do
                if v then
                    local scategory, smember = v:match("([^,]+),([^,]+)")
                    scategory = tonumber(scategory)
                    smember = tonumber(smember)
                    if scategory and smember then
                        eventTable.switches[key] = system.getSource({ category = scategory, member = smember })
                    end  
                end    
            end
            eventTable.units = rfsuite.tasks.telemetry.listSensorAudioUnits() 
        end


        -- Handle switch events
        for key, sensor in pairs(eventTable.switches) do
            local currentState = sensor:state()             -- true if switch is ON
            local prevState = lastSwitchState[key] or false
            local currentTime = os.clock()                  -- time in seconds
            local lastTime = lastPlayTime[key] or 0
            local shouldPlay = false

            if currentState then
                -- If switch was just toggled ON: play immediately
                if not prevState then
                    shouldPlay = true
                -- If switch is held ON: throttle to once every 10s
                elseif (currentTime - lastTime) >= 10 then
                    shouldPlay = true
                end

                if shouldPlay then
                    local sensorSrc = rfsuite.tasks.telemetry.getSensorSource(key)
                    local value = sensorSrc:value()
                    if value and type(value) == "number" then

                        local unit = eventTable.units[key]
                        local decimals = tonumber(sensorSrc:decimals())

                        system.playNumber(value,unit,decimals)
                        lastPlayTime[key] = currentTime
                    
                    end
                end
            end

            -- Update state
            lastSwitchState[key] = currentState
        end


    else
        telemetryStartTime = nil  -- Reset when telemetry disconnects
    end
end

function events.resetSwitchStates()
    eventTable.switches = {}
    lastPlayTime = {}
    lastSwitchState = {}
end


-- allow events table to be called from other modules
events.eventTable = eventTable

return events
