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

local switches = {}

-- Tables to track switch configurations and timing
local switchTable = {
    switches = {},
    units = {},
}

local lastPlayTime    = {}
local lastSwitchState = {}
local switchStartTime = nil

--------------------------------------------------------------------------------
-- Handles the wakeup event for switch-based telemetry audio playback.
--
-- Behavior:
--   • Populates `switchTable.switches` from user preferences if empty.
--   • Waits 5 seconds after telemetry becomes active before processing.
--   • For each configured switch:
--       - If toggled ON, plays telemetry value immediately.
--       - If held ON, throttles playback to once every 10 seconds.
--       - Retrieves sensor source, unit, and decimal precision.
--       - Calls `system.playNumber` to play the value.
--       - Updates `lastPlayTime` and `lastSwitchState`.
--
-- Dependencies:
--   • rfsuite.preferences.switches           – user-configured switch mapping
--   • system.getSource                        – retrieve switch source by (category, member)
--   • rfsuite.tasks.telemetry.listSensorAudioUnits
--   • rfsuite.tasks.telemetry.getSensorSource
--   • system.playNumber
--
-- Globals:
--   • switchTable.switches   – table storing switch source objects
--   • switchTable.units      – table mapping keys to audio units
--   • switchStartTime        – timestamp when switch processing began
--   • lastSwitchState        – previous ON/OFF state per switch key
--   • lastPlayTime           – last playback timestamp per switch key
--------------------------------------------------------------------------------
function switches.wakeup()
    local currentTime = os.clock()

    -- Populate switchTable if empty and preferences exist
    if next(switchTable.switches) == nil and rfsuite.preferences.switches then
        for key, v in pairs(rfsuite.preferences.switches) do
            if v then
                local scategory, smember = v:match("([^,]+),([^,]+)")
                scategory = tonumber(scategory)
                smember  = tonumber(smember)
                if scategory and smember then
                    switchTable.switches[key] = system.getSource({
                        category = scategory,
                        member   = smember
                    })
                end
            end
        end

        switchTable.units = rfsuite.tasks.telemetry.listSensorAudioUnits()
    end

    -- Initialize switchStartTime on first wakeup
    if not switchStartTime then
        switchStartTime = currentTime
    end

    -- Delay processing until 5 seconds after telemetry activation
    if (currentTime - switchStartTime) > 5 then
        for key, sensor in pairs(switchTable.switches) do
            local currentState = sensor:state()        -- true if switch is ON
            local prevState    = lastSwitchState[key] or false
            local now          = os.clock()
            local lastTime     = lastPlayTime[key] or 0
            local shouldPlay   = false

            if currentState then
                -- Just toggled ON → play immediately
                if not prevState then
                    shouldPlay = true
                -- Held ON → throttle to once every 10 seconds
                elseif (now - lastTime) >= 10 then
                    shouldPlay = true
                end

                if shouldPlay then
                    local sensorSrc = rfsuite.tasks.telemetry.getSensorSource(key)
                    if sensorSrc then
                        local value     = sensorSrc:value()
                        if value and type(value) == "number" then
                            local unit     = switchTable.units[key]
                            local decimals = tonumber(sensorSrc:decimals())
                            system.playNumber(value, unit, decimals)
                            lastPlayTime[key] = now
                        end
                    end    
                end
            end

            -- Update previous state for next cycle
            lastSwitchState[key] = currentState
        end
    end
end

--------------------------------------------------------------------------------
-- Resets switch state tables, allowing reconfiguration at runtime.
--------------------------------------------------------------------------------
function switches.resetSwitchStates()
    switchTable.switches   = {}
    lastPlayTime           = {}
    lastSwitchState        = {}
    switchStartTime        = nil
end

-- Expose switchTable for other modules
switches.switchTable = switchTable

return switches
