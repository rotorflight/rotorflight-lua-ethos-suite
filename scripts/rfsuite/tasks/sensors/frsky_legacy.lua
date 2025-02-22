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

* This script is called when using RF2.1 or lower. It is used to create, drop and rename sensors for the legacy frsky protocol

]] --
--
local arg = {...}
local config = arg[1]
local cacheExpireTime = 10 -- Time in seconds to expire the caches
local lastCacheFlushTime = os.clock() -- Store the initial time

local frsky_legacy = {}

-- create
local createSensorList = {}
createSensorList[0x5450] = {name = "Governor Flags", unit = UNIT_RAW}
createSensorList[0x5110] = {name = "Adj. Source", unit = UNIT_RAW}
createSensorList[0x5111] = {name = "Adj. Value", unit = UNIT_RAW}
createSensorList[0x5460] = {name = "Model ID", unit = UNIT_RAW}
createSensorList[0x5471] = {name = "PID Profile", unit = UNIT_RAW}
createSensorList[0x5472] = {name = "Rate Profile", unit = UNIT_RAW}
createSensorList[0x5440] = {name = "Throttle %", unit = UNIT_PERCENT}
createSensorList[0x5250] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x5462] = {name = "Arming Flags", unit = UNIT_RAW}

-- drop
local dropSensorList = {}
dropSensorList[0x0400] = {name = "Temp1"}
dropSensorList[0x0410] = {name = "Temp1"}

-- rename
local renameSensorList = {}
renameSensorList[0x0500] = {name = "Headspeed", onlyifname = "RPM"}
renameSensorList[0x0501] = {name = "Tailspeed", onlyifname = "RPM"}

renameSensorList[0x0210] = {name = "Voltage", onlyifname = "VFAS"}
renameSensorList[0x0200] = {name = "Current", onlyifname = "Current"}
renameSensorList[0x0600] = {name = "Charge Level", onlyifname = "Fuel"}
renameSensorList[0x0910] = {name = "Cell Voltage", onlyifname = "ADC4"}
renameSensorList[0x0900] = {name = "BEC Voltage", onlyifname = "ADC3"}

renameSensorList[0x0211] = {name = "ESC Voltage", onlyifname = "VFAS"}
renameSensorList[0x0201] = {name = "ESC Current", onlyifname = "Current"}
renameSensorList[0x0502] = {name = "ESC RPM", onlyifname = "RPM"}
renameSensorList[0x0B70] = {name = "ESC Temp", onlyifname = "ESC temp"}

renameSensorList[0x0212] = {name = "ESC2 Voltage", onlyifname = "VFAS"}
renameSensorList[0x0202] = {name = "ESC2 Current", onlyifname = "Current"}
renameSensorList[0x0503] = {name = "ESC2 RPM", onlyifname = "RPM"}
renameSensorList[0x0B71] = {name = "ESC2 Temp", onlyifname = "ESC temp"}

renameSensorList[0x0401] = {name = "MCU Temp", onlyifname = "Temp1"}
renameSensorList[0x0840] = {name = "Heading", onlyifname = "GPS course"}

frsky_legacy.createSensorCache = {}
frsky_legacy.dropSensorCache = {}
frsky_legacy.renameSensorCache = {}

local function createSensor(physId, primId, appId, frameValue)

    -- check for custom sensors and create them if they dont exist
    if createSensorList[appId] ~= nil then

        local v = createSensorList[appId]

        if frsky_legacy.createSensorCache[appId] == nil then

            frsky_legacy.createSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky_legacy.createSensorCache[appId] == nil then

                frsky_legacy.createSensorCache[appId] = model.createSensor()
                frsky_legacy.createSensorCache[appId]:name(v.name)
                frsky_legacy.createSensorCache[appId]:appId(appId)
                frsky_legacy.createSensorCache[appId]:physId(physId)
                frsky_legacy.createSensorCache[appId]:module(rfsuite.rssiSensor:module())

                frsky.createSensorCache[appId]:minimum(min or -1000000000)
                frsky_legacy.createSensorCache[appId]:maximum(max or 2147483647)
                if v.unit ~= nil then
                    frsky_legacy.createSensorCache[appId]:unit(v.unit)
                    frsky_legacy.createSensorCache[appId]:protocolUnit(v.unit)
                end
                if v.minimum ~= nil then frsky_legacy.createSensorCache[appId]:minimum(v.minimum) end
                if v.maximum ~= nil then frsky_legacy.createSensorCache[appId]:maximum(v.maximum) end

            end

        end
    end

end

local function dropSensor(physId, primId, appId, frameValue)

    -- check for custom sensors and create them if they dont exist
    if dropSensorList[appId] ~= nil then
        local v = dropSensorList[appId]

        if frsky_legacy.dropSensorCache[appId] == nil then
            frsky_legacy.dropSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky_legacy.dropSensorCache[appId] ~= nil then frsky_legacy.dropSensorCache[appId]:drop() end

        end

    end

end

local function renameSensor(physId, primId, appId, frameValue)

    -- check for custom sensors and create them if they dont exist
    if renameSensorList[appId] ~= nil then
        local v = renameSensorList[appId]

        if frsky_legacy.renameSensorCache[appId] == nil then
            frsky_legacy.renameSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky_legacy.renameSensorCache[appId] ~= nil then if frsky_legacy.renameSensorCache[appId]:name() == v.onlyifname then frsky_legacy.renameSensorCache[appId]:name(v.name) end end

        end

    end

end

local function telemetryPop()
    -- Pops a received SPORT packet from the queue. Please note that only packets using a data ID within 0x5000 to 0x50FF (frame ID == 0x10), as well as packets with a frame ID equal 0x32 (regardless of the data ID) will be passed to the LUA telemetry receive queue.
    local frame = rfsuite.tasks.msp.sensor:popFrame()
    if frame == nil then return false end

    if not frame.physId or not frame.primId then return end

    createSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    dropSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    renameSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    return true
end

function frsky_legacy.wakeup()

    -- Function to clear caches
    local function clearCaches()
        frsky_legacy.createSensorCache = {}
        frsky_legacy.renameSensorCache = {}
        frsky_legacy.dropSensorCache = {} -- We don't use this in this script, but keep it here in case the legacy script is used
    end

    -- Check if it's time to expire the caches
    if os.clock() - lastCacheFlushTime >= cacheExpireTime then
        clearCaches()
        lastCacheFlushTime = os.clock() -- Reset the timer
    end

    -- Flush sensor list if we kill the sensors
    if not rfsuite.tasks.telemetry.active() or not rfsuite.rssiSensor then clearCaches() end

    -- If GUI or queue is busy.. do not do this!
    if rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.tasks.telemetry.active() and rfsuite.rssiSensor then if rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then while telemetryPop() do end end end

end

return frsky_legacy
