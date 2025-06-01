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

local maxmin = {}

local lastSensorValues = {}
local sensorTable

-- Use os.clock() to throttle to once every 2 CPU‐seconds:
local lastTrackTime = 0

function maxmin.wakeup()
    -- Get CPU time in seconds since the Lua interpreter started
    local now = os.clock()

    -- If it has not been at least 2 seconds of CPU time since last tracking, skip
    if now - lastTrackTime < 2 then
        return
    end

    -- Update timestamp so next run must wait another 2 CPU‐seconds
    lastTrackTime = now

    -- Initialize sensor definitions if not already done
    if not sensorTable then
        sensorTable = rfsuite.tasks.telemetry.sensorTable
    end

    -- Ensure telemetry module is available
    if not telemetry then
        telemetry = rfsuite.tasks.telemetry
    end

    -- Track sensor max/min values
    for sensorKey, sensorDef in pairs(sensorTable) do
        local source = telemetry.getSensorSource(sensorKey)
        if source and source:state() then
            local val = source:value()
            if val then
                -- Determine whether to track this sensor
                local shouldTrack = false

                if type(sensorDef.maxmin_trigger) == "function" then
                    shouldTrack = sensorDef.maxmin_trigger()
                else
                    shouldTrack = sensorDef.maxmin_trigger
                end

                -- Record min/max if tracking is active
                if shouldTrack then
                    rfsuite.tasks.telemetry.sensorStats[sensorKey] =
                        rfsuite.tasks.telemetry.sensorStats[sensorKey] or {min = math.huge, max = -math.huge}

                    rfsuite.tasks.telemetry.sensorStats[sensorKey].min =
                        math.min(rfsuite.tasks.telemetry.sensorStats[sensorKey].min, val)
                    rfsuite.tasks.telemetry.sensorStats[sensorKey].max =
                        math.max(rfsuite.tasks.telemetry.sensorStats[sensorKey].max, val)
                end
            end
        end
    end
end

function maxmin.reset()
    rfsuite.tasks.telemetry.sensorStats = {} -- Clear min/max tracking
    lastSensorValues = {}                   -- Clear last sensor values
    -- Reset throttle timestamp so next wakeup always runs
    lastTrackTime = 0
end

return maxmin
