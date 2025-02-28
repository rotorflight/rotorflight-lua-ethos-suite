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
-- Rotorflight Custom Telemetry Decoder for ELRS
--
--
local arg = {...}
local config = arg[1]

local cacheExpireTime = 10 -- Time in seconds to expire the caches
local lastCacheFlushTime = os.clock() -- Store the initial time
local lastWakeupTime = 0  
local wakeupInterval = 0.5

local sim = {}

-- used in sensors.lua to know if state changes
sim.name = "sim"

-- get the sensors
local sensorList = rfsuite.tasks.telemetry.simSensors()

local sensors = {}
sensors['uid'] = {}
sensors['lastvalue'] = {}

local function createSensor(uid, name, unit, dec, value, min, max)

    sensors['uid'][uid] = model.createSensor()
    sensors['uid'][uid]:name(name)
    sensors['uid'][uid]:appId(uid)
    sensors['uid'][uid]:module(1)
    sensors['uid'][uid]:minimum(min or -1000000000)
    sensors['uid'][uid]:maximum(max or 2147483647)

    if dec or (dev and dec >= 1) then
        sensors['uid'][uid]:decimals(dec)
        sensors['uid'][uid]:protocolDecimals(dec)
    end
    if unit then
        sensors['uid'][uid]:unit(unit)
        sensors['uid'][uid]:protocolUnit(unit)
    end
    if value then sensors['uid'][uid]:value(value) end
end


function sim.wakeup()
    local now = os.clock()  -- Get current time in seconds (high precision)
    if now - lastWakeupTime >= wakeupInterval then


        for i, v in ipairs(sensorList) do
            local min = v.sensor.min
            local max = v.sensor.max
            local uid = v.sensor.uid
            local unit = v.sensor.unit
            local value = v.sensor.value
            local dec = v.sensor.dec
            local name = v.name
  
            if min ~= nil and max ~= nil and uid ~= nil and value ~= nil then
                -- create the sensors
                if sensors['uid'][uid] == nil then
                    sensors['uid'][uid] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
                    if sensors['uid'][uid] == nil then
                        rfsuite.utils.log("Create sensor: " .. uid, "info")
                        createSensor(uid, name, unit, dec, value, min, max)
                    end
                end

                -- update the sensors
                if sensors['uid'][uid] then
                    if type(value) == "function" then
                        sensors['uid'][uid]:value(value())
                    end
                end

                if sensors['uid'][uid] then
    
                    -- detect if sensor has been deleted or is missing after initial creation
                    if sensors['uid'][uid]:state() == false then
                        sensors['uid'][uid] = nil
                        sensors['lastvalue'][uid] = nil
                    end
        
                end        
            end
        end


        lastWakeupTime = now
    end
end

return sim
