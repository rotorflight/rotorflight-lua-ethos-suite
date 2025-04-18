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
local config = arg[1]

local cacheExpireTime = 30  -- Future-proofed, in case cache flush is implemented
local lastCacheFlushTime = os.clock()

local lastWakeupTime = 0
local wakeupInterval = 1
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
    ["0x0E60"] = true, ["0xF108"] = true, ["0x0730"] = true,
    ["0x0B20"] = true, ["0x7360"] = true, ["0x0B60"] = true
}

local sensors = {
    uid = {},
    lastvalue = {}
}

--[[
    Creates a sensor with the specified parameters and adds it to the sensors table.

    @param uid (number) - Unique identifier for the sensor.
    @param name (string) - Name of the sensor.
    @param unit (string) - Unit of measurement for the sensor (optional).
    @param dec (number) - Number of decimal places for the sensor value (optional).
    @param value (number) - Initial value of the sensor (optional).
    @param min (number) - Minimum value the sensor can report (optional, default is -1000000000).
    @param max (number) - Maximum value the sensor can report (optional, default is 2147483647).
]]
local function createSensor(uid, name, unit, dec, value, min, max)
    local sensor = model.createSensor()
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
end

--[[
    dropSensor(uid)
    
    This function drops a telemetry sensor source identified by the given unique identifier (uid).
    
    Parameters:
    uid (number) - The unique identifier of the telemetry sensor to be dropped.
    
    The function retrieves the telemetry sensor source using the provided uid and, if found, calls the drop method on the source to remove it.
]]
local function dropSensor(uid)
    local src = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
    if src then
        src:drop()
    end
end

--[[
    ensureSensorExists(uid, name, unit, dec, value, min, max)
    
    Ensures that a sensor with the specified UID exists. If the sensor does not exist, it attempts to find an existing sensor with the given UID.
    If an existing sensor is found, it is added to the sensors table. If no existing sensor is found, a new sensor is created with the provided parameters.
    
    Parameters:
    uid (string)   - Unique identifier for the sensor.
    name (string)  - Name of the sensor.
    unit (string)  - Unit of measurement for the sensor.
    dec (number)   - Decimal precision for the sensor value.
    value (number) - Initial value of the sensor.
    min (number)   - Minimum value for the sensor.
    max (number)   - Maximum value for the sensor.
]]
local function ensureSensorExists(uid, name, unit, dec, value, min, max)
    if not sensors.uid[uid] then
        local existingSensor = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = uid})
        if existingSensor then
            sensors.uid[uid] = existingSensor
        else
            rfsuite.utils.log("Create sensor: " .. uid, "info")
            createSensor(uid, name, unit, dec, value, min, max)
        end
    end
end

--[[
    Updates the value of a sensor identified by its unique identifier (uid).

    @param uid (string) - The unique identifier of the sensor.
    @param value (number | function) - The new value to set for the sensor. 
                                       If a function is provided, it will be called to get the value.
]]
local function updateSensorValue(uid, value)
    if sensors.uid[uid] then
        if type(value) == "function" then
            value = value()
        end
        sensors.uid[uid]:value(value)
    end
end

--[[
    Function: flushCacheIfNeeded
    Description: This function checks if the cache needs to be flushed based on the elapsed time since the last cache flush. 
                 If the elapsed time is greater than or equal to the cache expiration time, it clears the sensor UID and last value caches, 
                 and updates the last cache flush time to the current time.
    Parameters: None
    Returns: None
]]
local function flushCacheIfNeeded()
    if os.clock() - lastCacheFlushTime >= cacheExpireTime then
        sensors.uid = {}
        sensors.lastvalue = {}
        lastCacheFlushTime = os.clock()
    end
end

--[[
    dropAutoDiscoveredSensors

    This function iterates over the `dropList` table and calls the `dropSensor` function
    for each unique identifier (uid) found in the `dropList`. It is used to remove or 
    drop sensors that have been automatically discovered.

    Parameters:
    None

    Returns:
    None
]]
local function dropAutoDiscoveredSensors()
    for uid in pairs(dropList) do
        dropSensor(uid)
    end
end

--[[
    handleSensors function iterates through a list of sensors and processes each sensor's data.
    
    For each sensor in the sensorList:
    - Extracts the sensor's unique identifier (uid), name, unit, decimal precision (dec), current value, minimum value, and maximum value.
    - If the uid, min, max, and value are all present:
        - Calls ensureSensorExists to ensure the sensor is registered with the given parameters.
        - Calls updateSensorValue to update the sensor's current value.
]]
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

--[[
    The `wakeup` function is responsible for periodically handling sensor updates and cache management.
    
    It performs the following tasks:
    1. Checks the current time using `os.clock()`.
    2. If the elapsed time since the last wakeup is greater than or equal to `wakeupInterval`, it calls `handleSensors()` to process sensor data and updates `lastWakeupTime`.
    3. If it is the first run or the elapsed time since the last drop is greater than or equal to `wakeupIntervalDrop`, it calls `dropAutoDiscoveredSensors()` to remove automatically discovered sensors, updates `lastWakeupTimeDrop`, and sets `firstRun` to false.
    4. Calls `flushCacheIfNeeded()` to manage the cache if necessary.
--]]
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

sim.wakeup = wakeup
return sim
