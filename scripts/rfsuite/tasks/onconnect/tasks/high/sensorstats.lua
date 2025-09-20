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

local sensorstats = {}

local runOnce = false

function sensorstats.wakeup()

    -- quick exit if no apiVersion
    if rfsuite.session.apiVersion == nil then return end    

    if rfsuite.session.mspBusy then return end    

    if rfsuite.tasks.telemetry then
        rfsuite.tasks.telemetry.sensorStats = {}
        runOnce = true
    end
end

function sensorstats.reset()
    runOnce = false
end

function sensorstats.isComplete()
    return runOnce
end

return sensorstats