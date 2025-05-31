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

function maxmin.wakeup()

    if not rfsuite.session.flightMode == "inflight" then
        return
    end

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
                -- Check optional per-sensor trigger
                local shouldTrack = false

                --[[
                    Determines whether telemetry tracking should be enabled based on various sensor conditions.

                    The logic follows these rules:
                    1. If `sensorDef.maxmin_trigger` is a function, its return value decides tracking.
                    2. If the session is armed and the "governor" sensor exists with a value of 4, tracking is enabled.
                    3. If the session is armed and the "rpm" sensor exists with a value greater than 500, tracking is enabled.
                    4. If the session is armed and the "throttle_percent" sensor exists with a value greater than 30, tracking is enabled.
                    5. If the session is armed (fallback), tracking is enabled.
                    6. Otherwise, tracking is disabled.

                    Variables:
                    - sensorDef: Table containing sensor definitions, possibly with a custom trigger function.
                    - shouldTrack: Boolean flag indicating whether telemetry tracking should occur.
                    - rfsuite.session.isArmed: Boolean indicating if the session is currently armed.
                    - telemetry.getSensorSource: Function to retrieve sensor data by name.
                ]]
                if type(sensorDef.maxmin_trigger) == "function" then
                    shouldTrack = sensorDef.maxmin_trigger()
                else    
                    shouldTrack = sensorDef.maxmin_trigger
                end


                -- Record min/max if tracking is active
                if shouldTrack then
                    rfsuite.tasks.telemetry.sensorStats[sensorKey] = rfsuite.tasks.telemetry.sensorStats[sensorKey] or {min = math.huge, max = -math.huge}
                    rfsuite.tasks.telemetry.sensorStats[sensorKey].min = math.min(rfsuite.tasks.telemetry.sensorStats[sensorKey].min, val)
                    rfsuite.tasks.telemetry.sensorStats[sensorKey].max = math.max(rfsuite.tasks.telemetry.sensorStats[sensorKey].max, val)
                end
            end
        end
    end


end

function maxmin.reset()
    rfsuite.tasks.telemetry.sensorStats = {} -- Clear min/max tracking
    lastSensorValues = {} -- clear last sensor values
end

return maxmin
