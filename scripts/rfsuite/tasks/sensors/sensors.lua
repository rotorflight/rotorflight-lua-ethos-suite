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
--
local arg = {...}
local config = arg[1]

local sensors = {}

sensors.elrs = assert(loadfile("tasks/sensors/elrs.lua"))(config)
sensors.frsky_legacy = assert(loadfile("tasks/sensors/frsky_legacy.lua"))(config)
sensors.frsky = assert(loadfile("tasks/sensors/frsky.lua"))(config)

function sensors.wakeup()

    -- we cant do anything if bg task not running
    if not rfsuite.tasks.active() then return end

    -- we cant do anything if we have no msp
    if not rfsuite.session.apiVersion then return end

    if rfsuite.tasks.msp.protocol.mspProtocol == "crsf" and rfsuite.preferences.internalElrsSensors == true then sensors.elrs.wakeup() end

    if rfsuite.tasks.msp.protocol.mspProtocol == "smartPort" and rfsuite.preferences.internalSportSensors == true then

        if rfsuite.session.apiVersion >= 12.08 then
            -- use new if msp is 12.08 or higher
            sensors.frsky.wakeup()
        else
            -- use legacy if msp is lower than 12.08
            sensors.frsky_legacy.wakeup()
        end
    end

end

return sensors
