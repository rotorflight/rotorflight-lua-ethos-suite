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

local switchTable = {
    switches = {},
    units = {},
}

local lastPlayTime    = {}
local lastSwitchState = {}
local switchStartTime = nil

local validCache          = {}
local lastValidityCheck   = {}
local VALIDITY_RECHECK_SEC = 5

--- Initializes the switchTable with switch sources and sensor audio units based on user preferences.
-- 
-- This function retrieves the user's switch preferences from `rfsuite.preferences.switches`.
-- For each valid preference entry, it parses the category and member values, converts them to numbers,
-- and uses `system.getSource` to obtain the corresponding switch source, which is then stored in `switchTable.switches`.
-- Finally, it populates `switchTable.units` with the list of sensor audio units from telemetry.
--
-- @function initializeSwitches
-- @usage
--   initializeSwitches()
-- @see rfsuite.preferences.switches
-- @see system.getSource
-- @see rfsuite.tasks.telemetry.listSensorAudioUnits
local function initializeSwitches()
    local prefs = rfsuite.preferences.switches
    if not prefs then return end

    for key, v in pairs(prefs) do
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

--- Handles the periodic wakeup logic for monitoring and announcing switch states.
-- 
-- This function checks the state of switches defined in `switchTable.switches`.
-- It initializes the switches if they are not already set up, and ensures that
-- at least 5 seconds have passed since the function was first called before processing.
--
-- For each switch:
--   - If the switch is active and either was previously inactive or at least 10 seconds
--     have passed since the last announcement, it plays the current sensor value using
--     `system.playNumber`.
--   - The function tracks the last state and last play time for each switch to avoid
--     repeated announcements.
--
-- Dependencies:
--   - `os.clock()`: Current time reference.
--   - `switchTable.switches`: Table of switch sensor objects.
--   - `rfsuite.tasks.telemetry.getSensorSource(key)`: Retrieves the sensor source for a switch.
--   - `system.playNumber(value, unit, decimals)`: Announces the sensor value.
--
-- Globals used:
--   - `switchStartTime`: Timestamp of the first wakeup call.
--   - `lastSwitchState`: Table storing the last known state of each switch.
--   - `lastPlayTime`: Table storing the last announcement time for each switch.
--
-- No return value.
function switches.wakeup()
    local now = os.clock()

    if next(switchTable.switches) == nil then
        initializeSwitches()
    end

    if not switchStartTime then
        switchStartTime = now
    end

    if (now - switchStartTime) <= 5 then return end

    -- only revalidate in preflight
    local mode = (rfsuite and rfsuite.flightmode and rfsuite.flightmode.current) or nil
    local allowRecheck = (mode == "preflight")

    for key, sensor in pairs(switchTable.switches) do
        -- use cached validity unless we need to refresh
        local isValid   = validCache[key]
        local lastChk   = lastValidityCheck[key] or 0
        local needCheck = (isValid == nil) or (allowRecheck and (now - lastChk) >= VALIDITY_RECHECK_SEC)

        if needCheck then
            -- heavy call, but only when needed (first time, or every 5s in preflight)
            local s = sensor:state()
            validCache[key]        = (s == true)
            lastValidityCheck[key] = now
        end

        local currentState = validCache[key] == true
        if not currentState then goto continue end

        -- existing announce timing
        local prevState = lastSwitchState[key] or false
        local lastTime  = lastPlayTime[key] or 0
        local playNow   = false

        if not prevState or (now - lastTime) >= 10 then
            playNow = true
        end

        if playNow then
            local sensorSrc = rfsuite.tasks.telemetry.getSensorSource(key)
            if sensorSrc then
                local value = sensorSrc:value()
                if value and type(value) == "number" then
                    local unit     = switchTable.units[key]
                    local decimals = tonumber(sensorSrc:decimals())
                    system.playNumber(value, unit, decimals)
                    lastPlayTime[key] = now
                end
            end
        end

        lastSwitchState[key] = currentState
        ::continue::
    end
end

--- Resets the state of all switches and related tracking variables.
-- This function clears the `switchTable.switches` table, resets the `lastPlayTime`
-- and `lastSwitchState` tables, and sets `switchStartTime` to nil.
-- It is typically used to reinitialize switch states, for example when starting a new task or event.
function switches.resetSwitchStates()
    switchTable.switches   = {}
    lastPlayTime           = {}
    lastSwitchState        = {}
    switchStartTime        = nil
    validCache             = {}
    lastValidityCheck      = {}
end

--- Assigns the provided `switchTable` to the `switches.switchTable` property.
-- This allows access to the table of switch configurations or states via the `switches` module.
-- @field switchTable table: A table containing switch definitions or states.
switches.switchTable = switchTable

return switches