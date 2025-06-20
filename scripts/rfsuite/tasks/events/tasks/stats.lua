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

-- Optimized stats.lua

local arg = { ... }
local config = arg[1]

local stats = {}

local fullSensorTable = nil
local filteredSensors = nil
local lastTrackTime = 0

local telemetry

local function buildFilteredList()
    filteredSensors = {}

    for sensorKey, sensorDef in pairs(fullSensorTable) do
        local mt = sensorDef.stats

        if mt == true then
            filteredSensors[sensorKey] = sensorDef

        elseif type(mt) == "function" then
            local ok, result = pcall(mt)
            if ok and result then
                filteredSensors[sensorKey] = sensorDef
            end
        end
    end
end

function stats.wakeup()

    -- we start this in wakeup as telemetry may not be set when this tasks starts
    if not telemetry then
        telemetry = rfsuite.tasks.telemetry
        return
    end

    if rfsuite.session.flightMode ~= "inflight" then return end

    local now = rfsuite.clock
    if now - lastTrackTime < 0.25 then return end
    lastTrackTime = now

    if not fullSensorTable then
        fullSensorTable = telemetry.sensorTable
        if not fullSensorTable then return end
        buildFilteredList()
    end

    if not telemetry.sensorStats then
        telemetry.sensorStats = {}
    end

    local statsTable = telemetry.sensorStats

    for sensorKey, _ in pairs(filteredSensors) do
        local val = telemetry.getSensor(sensorKey)
        if val and type(val) == "number" then
            if not statsTable[sensorKey] then
                statsTable[sensorKey] = {
                    min = math.huge,
                    max = -math.huge,
                    sum = 0,
                    count = 0,
                    avg = 0
                }
            end

            local entry = statsTable[sensorKey]
            entry.min   = math.min(entry.min, val)
            entry.max   = math.max(entry.max, val)
            entry.sum   = entry.sum + val
            entry.count = entry.count + 1
            entry.avg   = entry.sum / entry.count
        end
    end
end

function stats.reset()
    telemetry.sensorStats = {}
    fullSensorTable  = nil
    filteredSensors  = nil
    lastTrackTime    = 0
end

return stats

