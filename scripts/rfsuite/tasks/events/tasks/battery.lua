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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]--

local batteryevents = {}

local lastConfig = nil

-- Deep equality check for tables
local function deepEqual(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do
        if not deepEqual(v, b[k]) then return false end
    end
    for k, v in pairs(b) do
        if not deepEqual(v, a[k]) then return false end
    end
    return true
end

-- Deep copy function for tables
local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do
        c[k] = deepCopy(v)
    end
    return c
end

function batteryevents.wakeup()
    local config = rfsuite.session.batteryConfig
    if not config then
        lastConfig = nil
        return
    end

    -- Only run this check once per cycle
    if not lastConfig or not deepEqual(config, lastConfig) then
        -- If the config has changed, call the fuel logic reset function
        if rfsuite.tasks.telemetry and rfsuite.tasks.telemetry.fuelReset then
            rfsuite.tasks.telemetry.fuelReset()
        end
        -- Update the cached config using deep copy
        lastConfig = deepCopy(config)
    end
end

return batteryevents

