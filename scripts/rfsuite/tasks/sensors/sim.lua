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
local arg = {...}
local config = arg[1] or {}

-- =====================================================================
-- CPU optimizations applied:
-- 1) Increase default wakeup interval (still overridable by config)
-- 2) Avoid redundant sensor :value() writes via sensors.lastvalue cache
-- 3) Guarantee refresh every 5s even if value unchanged
-- =====================================================================

local cacheExpireTime = 30  -- Future-proofed, in case cache flush is implemented
local lastCacheFlushTime = os.clock()

local lastWakeupTime = 0
-- Default slowed from 1s -> 2s; can be overridden via config.sim.wakeupInterval
local wakeupInterval = (config.sim and config.sim.wakeupInterval) or 2
local lastWakeupTimeDrop = 0
local wakeupIntervalDrop = 120
local firstRun = true

local sim = {}
sim.name = "sim"

local sensorList = rfsuite.tasks.telemetry.simSensors()

-- Drop list as a set-like table (only care about keys)
local dropList = {
    ["0xF104"] = true, ["0x0300"] = true, ["0x0301"] = true,
    ["0x0100"] = true, ["0x0110"] = true, ["0x0500"] = true,
    ["0x0200"] = true, ["0x0800"] = true, ["0x0850"] = true,
    ["0x0830"] = true, ["0x0820"] = true, ["0x0840"] = true,
    ["0xF103"] = true, ["0x0A00"] = true, ["0x0210"] = true,
    ["0x0B20"] = true, ["0x0730"] = true, ["0xF108"] = true,
    ["0x0B60"] = true, ["0x0D50"] = true, ["0x0D10"] = true,
    ["0x0D20"] = true, ["0x0D40"] = true, ["0x0D00"] = true,
    ["0x0D30"] = true, ["0x0D60"] = true, ["0x0D70"] = true,
    ["0x0E60"] = true, ["0x7360"] = true,
}

local sensors = {
    uid = {},
    lastvalue = {},
    lastupdate = {}
}

local REFRESH_INTERVAL = 5 -- seconds, force update even if unchanged

--[[
    Creates a sensor with the specified parameters and adds it to the sensors table.
]]
local function createSensor(uid, name, unit, dec, value, min, max)
    local sensor = model.createSensor({type=SENSOR_TYPE_DIY})
    sensor:name(name)
    sensor:appId(uid)
    sensor:module(rfsuite.session.telemetrySensor:module())
    sensor:minimum(min or -1000000000)
    sensor:maximum(max or 2147483647)

    if dec and dec >= 1 then
        sensor:decimals(dec)
        sensor:protocolDecimals(dec)
    end

    if unit then
        sensor:unit(unit)
        sensor:protocolUnit(unit)
    end

    if value then sensor:value(value) end

    sensors.uid[uid] = sensor
    sensors.lastvalue[uid] = value
    sensors.lastupdate[uid] = os.clock()
end

local function dropSensor(uid)
    local src = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
    if src then
        src:drop()
    end
end

local function ensureSensorExists(uid, name, unit, dec, value, min, max)
    if not sensors.uid[uid] then
        local existingSensor = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
        if existingSensor then
            sensors.uid[uid] = existingSensor
            sensors.lastupdate[uid] = os.clock()
        else
            rfsuite.utils.log("Create sensor: " .. uid, "info")
            createSensor(uid, name, unit, dec, value, min, max)
        end
    end
end

--[[
    Updates the value of a sensor identified by its unique identifier (uid).
    Only writes if changed OR if > REFRESH_INTERVAL since last update.
]]
local function updateSensorValue(uid, value)
    if sensors.uid[uid] then
        if type(value) == "function" then
            value = value()
        end
        local now = os.clock()
        local lastVal = sensors.lastvalue[uid]
        local lastUpdate = sensors.lastupdate[uid] or 0
        if value ~= lastVal or (now - lastUpdate) >= REFRESH_INTERVAL then
            sensors.uid[uid]:value(value)
            sensors.lastvalue[uid] = value
            sensors.lastupdate[uid] = now
        end
    end
end

local function flushCacheIfNeeded()
    if os.clock() - lastCacheFlushTime >= cacheExpireTime then
        sensors.uid = {}
        sensors.lastvalue = {}
        sensors.lastupdate = {}
        lastCacheFlushTime = os.clock()
    end
end

local function dropAutoDiscoveredSensors()
    for uid in pairs(dropList) do
        dropSensor(uid)
    end
end

local function handleSensors()
    for _, v in ipairs(sensorList) do
        local uid, name, unit, dec, value, min, max = 
            v.sensor.uid, v.name, v.sensor.unit, v.sensor.dec, v.sensor.value, v.sensor.min, v.sensor.max

        if uid and min and max and value then
            ensureSensorExists(uid, name, unit, dec, value, min, max)
            updateSensorValue(uid, value)
        end
    end
end

local function wakeup()
    local now = os.clock()

    if now - lastWakeupTime >= wakeupInterval then
        handleSensors()
        lastWakeupTime = now
    end

    if firstRun or now - lastWakeupTimeDrop >= wakeupIntervalDrop then
        dropAutoDiscoveredSensors()
        lastWakeupTimeDrop = now
        firstRun = false
    end

    flushCacheIfNeeded()
end

-- reset
function sim.reset()
    sensors.uid = {}
    sensors.lastvalue = {}
    sensors.lastupdate = {}
end

sim.wakeup = wakeup
return sim
