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
-- local cacheExpireTime = 10 -- Time in seconds to expire the caches (disabled)
-- local lastCacheFlushTime = os.clock() -- Store the initial time (disabled)
-- (Periodic cache flush disabled; using event-driven clears)

local frsky_legacy = {}

-- used by sensors.lua to know if module has changed
frsky_legacy.name = "frsky_legacy"

-- Bounded drain controls (tune as needed)
local MAX_FRAMES_PER_WAKEUP = 32
local MAX_TIME_BUDGET      = 0.004


--[[
createSensorList: A table mapping sensor IDs to their respective sensor details.
    - 0x5450: Governor Flags (UNIT_RAW)
    - 0x5110: Adj. Source (UNIT_RAW)
    - 0x5111: Adj. Value (UNIT_RAW)
    - 0x5460: Model ID (UNIT_RAW)
    - 0x5471: PID Profile (UNIT_RAW)
    - 0x5472: Rate Profile (UNIT_RAW)
    - 0x5440: Throttle % (UNIT_PERCENT)
    - 0x5250: Consumption (UNIT_MILLIAMPERE_HOUR)
    - 0x5462: Arming Flags (UNIT_RAW)

dropSensorList: A table mapping sensor IDs to their respective sensor names to be dropped.
    - 0x0400: Temp1
    - 0x0410: Temp1

renameSensorList: A table mapping sensor IDs to their new names, with conditions on the current name.
    - 0x0500: Headspeed (only if name is "RPM")
    - 0x0501: Tailspeed (only if name is "RPM")
    - 0x0210: Voltage (only if name is "VFAS")
    - 0x0200: Current (only if name is "Current")
    - 0x0600: Charge Level (only if name is "Fuel")
    - 0x0910: Cell Voltage (only if name is "ADC4")
    - 0x0900: BEC Voltage (only if name is "ADC3")
    - 0x0211: ESC Voltage (only if name is "VFAS")
    - 0x0201: ESC Current (only if name is "Current")
    - 0x0502: ESC RPM (only if name is "RPM")
    - 0x0B70: ESC Temp (only if name is "ESC temp")
    - 0x0212: ESC2 Voltage (only if name is "VFAS")
    - 0x0202: ESC2 Current (only if name is "Current")
    - 0x0503: ESC2 RPM (only if name is "RPM")
    - 0x0B71: ESC2 Temp (only if name is "ESC temp")
    - 0x0401: MCU Temp (only if name is "Temp1")
    - 0x0840: Heading (only if name is "GPS course")
]]
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

-- Track once-only ops to avoid repeated work
frsky_legacy.renamed = {}
frsky_legacy.dropped = {}


--[[
    createSensor - Creates a custom sensor if it does not already exist in the cache.

    Parameters:
    physId (number) - The physical ID of the sensor.
    primId (number) - The primary ID of the sensor.
    appId (number) - The application ID of the sensor.
    frameValue (number) - The frame value of the sensor.

    This function checks if a custom sensor with the given appId exists in the createSensorList.
    If it does, it then checks if the sensor is already cached in frsky_legacy.createSensorCache.
    If the sensor is not cached, it creates a new sensor, sets its properties, and caches it.
]]
-- createSensor: return a status
local function createSensor(physId, primId, appId, frameValue)
    if rfsuite.session.apiVersion == nil then return "skip" end
    local v = createSensorList[appId]
    if not v then return "skip" end

    if frsky.createSensorCache[appId] == nil then
        frsky.createSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        if frsky.createSensorCache[appId] == nil then
            local s = model.createSensor()
            s:name(v.name)
            s:appId(appId)
            s:physId(physId)
            s:module(rfsuite.session.telemetrySensor:module())
            s:minimum(min or -1000000000)
            s:maximum(max or 2147483647)
            if v.unit     then s:unit(v.unit); s:protocolUnit(v.unit) end
            if v.decimals then s:decimals(v.decimals); s:protocolDecimals(v.decimals) end
            if v.minimum  then s:minimum(v.minimum) end
            if v.maximum  then s:maximum(v.maximum) end
            frsky.createSensorCache[appId] = s
            return "created"
        end
    end

    return "noop"  -- already present
end

--[[
    dropSensor - Function to handle the dropping of a sensor based on its application ID.
    
    Parameters:
    physId (number) - The physical ID of the sensor.
    primId (number) - The primary ID of the sensor.
    appId (number) - The application ID of the sensor.
    frameValue (number) - The frame value associated with the sensor.
    
    This function checks if a custom sensor exists in the dropSensorList using the provided appId.
    If the sensor exists and is not already cached in frsky_legacy.dropSensorCache, it retrieves the sensor
    source using system.getSource and drops it if successfully retrieved.
]]
-- dropSensor: return a status (optional, only if you actually use dropSensorList here)
local function dropSensor(physId, primId, appId, frameValue)
    if rfsuite.session.apiVersion == nil then return "skip" end
    if not dropSensorList or not dropSensorList[appId] then return "skip" end

    if frsky.dropSensorCache[appId] == nil then
        local src = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        frsky.dropSensorCache[appId] = src or false
    end
    local src = frsky.dropSensorCache[appId]
    if src and src ~= false then
        if not frsky.dropped[appId] then
            src:drop()
            frsky.dropped[appId] = true
            return "dropped"
        end
        return "noop"
    end
    return "skip"
end


--[[
    renameSensor - Renames a telemetry sensor based on provided parameters.

    Parameters:
    physId (number) - The physical ID of the sensor.
    primId (number) - The primary ID of the sensor.
    appId (number) - The application ID of the sensor.
    frameValue (number) - The frame value of the sensor.

    This function checks if a custom sensor exists in the renameSensorList using the appId.
    If the sensor exists and is not already cached in frsky_legacy.renameSensorCache, it retrieves the sensor source.
    If the sensor source is found and its name matches the specified condition, it renames the sensor.
]]
local function renameSensor(physId, primId, appId, frameValue)
    if rfsuite.session.apiVersion == nil then return "skip" end
    local v = renameSensorList[appId]
    if not v then return "skip" end
    if frsky.renamed[appId] then return "noop" end

    if frsky.renameSensorCache[appId] == nil then
        local src = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        frsky.renameSensorCache[appId] = src or false
    end
    local src = frsky.renameSensorCache[appId]
    if src and src ~= false then
        if src:name() == v.onlyifname then
            src:name(v.name)
            frsky.renamed[appId] = true
            return "renamed"
        end
        return "noop"
    end
    return "skip"
end


--[[
    Function: telemetryPop
    Description: Pops a received SPORT packet from the queue and processes it. 
                 Only packets using a data ID within 0x5000 to 0x50FF (frame ID == 0x10), 
                 as well as packets with a frame ID equal to 0x32 (regardless of the data ID) 
                 will be passed to the LUA telemetry receive queue.
    Returns: 
        - true if a frame was processed
        - false if no frame was available
    Note: 
        - The function calls createSensor, dropSensor, and renameSensor with the frame's 
          physical ID, primary ID, application ID, and value.
--]]
-- telemetryPop: short-circuit based on status
local function telemetryPop()
    local frame = rfsuite.tasks.msp.sensorTlm:popFrame()
    if frame == nil then return false end
    if not frame.physId or not frame.primId then return false end

    local physId, primId, appId, value = frame:physId(), frame:primId(), frame:appId(), frame:value()

    -- 1) If this appId belongs to create list and we created/found it, we can skip rename/drop
    local cs = createSensor(physId, primId, appId, value)
    if cs ~= "skip" then return true end   -- handled or confirmed not needed; nothing else to do

    -- 2) If you’re actively dropping legacy sensors, try that next
    local ds = dropSensor(physId, primId, appId, value)
    if ds ~= "skip" then return true end

    -- 3) Finally, try a conditional rename
    renameSensor(physId, primId, appId, value)
    return true
end

--[[
    Function: frsky_legacy.wakeup
    Description: This function is responsible for managing sensor caches and ensuring they are cleared at appropriate times. It checks if the caches need to be expired based on a timer and clears them if necessary. Additionally, it flushes the sensor list if telemetry is inactive or if the RSSI sensor is not available. The function also ensures that certain operations are only performed when the GUI is not running and the MSP queue is processed.
    Short: Manages sensor caches and ensures timely clearing.
--]]
function frsky_legacy.wakeup()

    -- Function to clear caches
    local function clearCaches()
        frsky_legacy.createSensorCache = {}
        frsky_legacy.renameSensorCache = {}
        frsky_legacy.dropSensorCache = {} -- We don't use this in this script, but keep it here in case the legacy script is used
    end

    -- Periodic cache expiry removed (was causing bursts). Use event-driven clears only.

    -- Flush sensor list if telemetry is inactive
    if not rfsuite.session.telemetryState or not rfsuite.session.telemetrySensor then clearCaches() end

    -- If GUI idle and MSP queue processed, drain with a budget
    if rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.session.telemetryState and rfsuite.session.telemetrySensor then
        if rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then
            local start = os.clock()
            local count = 0
            while count < MAX_FRAMES_PER_WAKEUP and (os.clock() - start) <= MAX_TIME_BUDGET do
                if not telemetryPop() then break end
                count = count + 1
            end
        end
    end

end

function frsky_legacy.reset()
    frsky_legacy.createSensorCache = {}
    frsky_legacy.renameSensorCache = {}
    frsky_legacy.dropSensorCache = {}
    frsky_legacy.renamed = {}
    frsky_legacy.dropped = {}
end

return frsky_legacy
