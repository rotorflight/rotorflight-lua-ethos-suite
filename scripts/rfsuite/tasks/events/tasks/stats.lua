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

local stats = {}

-- Full sensorTable reference (rfsuite.tasks.telemetry.sensorTable)
local fullSensorTable = nil
-- After one pass, this holds only the sensors we’ll actually track
-- Format: { [sensorKey] = sensorDef, ... }
local filteredSensors = nil

-- Throttle tracking to once every 2 CPU‐seconds:
local lastTrackTime = 0

-- Build filteredSensors exactly once:
local function buildFilteredList()
    filteredSensors = {}

    for sensorKey, sensorDef in pairs(fullSensorTable) do
        local mt = sensorDef.stats

        -- Include if it's a literal true:
        if mt == true then
            filteredSensors[sensorKey] = sensorDef

        -- Or if it's a function that returns true right now:
        elseif type(mt) == "function" then
            -- Call it once. If it says “true”, include:
            local ok, result = pcall(mt)
            if ok and result then
                filteredSensors[sensorKey] = sensorDef
            end
        end
        -- Anything else (false, nil, or function returning false) is skipped
    end
end

function stats.wakeup()

    -- we should only build stats when 'inflight'
    if rfsuite.session.flightMode ~= "inflight" then
        return
    end

    -- Throttle: only run once every 0.25 CPU‐seconds
    local now = rfsuite.clock
    if now - lastTrackTime < 0.25 then
        return
    end
    lastTrackTime = now

    -- On the very first wakeup, grab the full sensorTable and build the filtered list
    if not fullSensorTable then
        fullSensorTable = rfsuite.tasks.telemetry.sensorTable
        if not fullSensorTable then
            -- Telemetry not ready yet
            return
        end

        buildFilteredList()
    end

    -- Ensure telemetry module is available
    if not telemetry then
        telemetry = rfsuite.tasks.telemetry
    end

    -- Initialize sensorStats if it doesn't exist
    if not rfsuite.tasks.telemetry.sensorStats then
        rfsuite.tasks.telemetry.sensorStats = {}
    end

    local statsTable = rfsuite.tasks.telemetry.sensorStats

    -- Now iterate only over filteredSensors—no more checks of stats
    for sensorKey, sensorDef in pairs(filteredSensors) do
        local source = telemetry.getSensorSource(sensorKey)
        if source and source:state() then
            local val = source:value()
            if val then
                local stats = statsTable[sensorKey] or { min = math.huge, max = -math.huge, sum = 0, count = 0, avg = 0 }
                stats.min = math.min(stats.min, val)
                stats.max = math.max(stats.max, val)
                stats.sum = stats.sum + val
                stats.count = stats.count + 1
                stats.avg = stats.sum / stats.count
                statsTable[sensorKey] = stats
            end
        end
    end
end

function stats.reset()
    -- Clear all stored stats and force a full rebuild on next wakeup()
    rfsuite.tasks.telemetry.sensorStats = {}
    fullSensorTable  = nil
    filteredSensors  = nil
    lastTrackTime    = 0
end

return stats
