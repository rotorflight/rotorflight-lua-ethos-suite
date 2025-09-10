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

local frsky = {}

frsky.name = "frsky"

-- Bounded drain controls (tune as needed)
local MAX_FRAMES_PER_WAKEUP = 32
local MAX_TIME_BUDGET      = 0.004

local dropSensorList = {}

--[[
createSensorList:
    This table maps sensor IDs to their respective sensor details, including name, unit, and optional decimals.
    - Example entries:
        - [0x5100] = {name = "Heartbeat", unit = UNIT_RAW}
        - [0x51A0] = {name = "Pitch Control", unit = UNIT_DEGREE, decimals = 2}

renameSensorList:
    This table maps sensor IDs to their new names, conditional on their current names.
    - Example entries:
        - [0x0500] = {name = "Headspeed", onlyifname = "RPM"}
        - [0x0210] = {name = "Voltage", onlyifname = "VFAS"}
]]
-- create
local createSensorList = {}
createSensorList[0x5100] = {name = "Heartbeat", unit = UNIT_RAW}
createSensorList[0x5250] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x5260] = {name = "Cell Count", unit = UNIT_RAW}
createSensorList[0x51A0] = {name = "Pitch Control", unit = UNIT_DEGREE, decimals = 2}
createSensorList[0x51A1] = {name = "Roll Control", unit = UNIT_DEGREE, decimals = 2}
createSensorList[0x51A2] = {name = "Yaw Control", unit = UNIT_DEGREE, decimals = 2}
createSensorList[0x51A3] = {name = "Collective Ctrl", unit = UNIT_DEGREE, decimals = 2}
createSensorList[0x51A4] = {name = "Throttle %", unit = UNIT_PERCENT, decimals = 1}
createSensorList[0x5258] = {name = "ESC1 Capacity", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x5268] = {name = "ESC1 Power", unit = UNIT_PERCENT}
createSensorList[0x5269] = {name = "ESC1 Throttle", unit = UNIT_PERCENT, decimals = 1}
createSensorList[0x5128] = {name = "ESC1 Status", unit = UNIT_RAW}
createSensorList[0x5129] = {name = "ESC1 Model ID", unit = UNIT_RAW}
createSensorList[0x525A] = {name = "ESC2 Capacity", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x512B] = {name = "ESC2 Model ID", unit = UNIT_RAW}
createSensorList[0x51D0] = {name = "CPU Load", unit = UNIT_PERCENT}
createSensorList[0x51D1] = {name = "System Load", unit = UNIT_PERCENT}
createSensorList[0x51D2] = {name = "RT Load", unit = UNIT_PERCENT}
createSensorList[0x5120] = {name = "Model ID", unit = UNIT_RAW}
createSensorList[0x5121] = {name = "Flight Mode", unit = UNIT_RAW}
createSensorList[0x5122] = {name = "Arm Flags", unit = UNIT_RAW}
createSensorList[0x5123] = {name = "Arm Dis Flags", unit = UNIT_RAW}
createSensorList[0x5124] = {name = "Rescue State", unit = UNIT_RAW}
createSensorList[0x5125] = {name = "Gov State", unit = UNIT_RAW}
createSensorList[0x5130] = {name = "PID Profile", unit = UNIT_RAW}
createSensorList[0x5131] = {name = "Rates Profile", unit = UNIT_RAW}
createSensorList[0x5110] = {name = "Adj Function", unit = UNIT_RAW}
createSensorList[0x5111] = {name = "Adj Value", unit = UNIT_RAW}
createSensorList[0x5210] = {name = "Heading", unit = UNIT_DEGREE, decimals = 1}
createSensorList[0x52F0] = {name = "Debug 0", unit = UNIT_RAW}
createSensorList[0x52F1] = {name = "Debug 1", unit = UNIT_RAW}
createSensorList[0x52F2] = {name = "Debug 2", unit = UNIT_RAW}
createSensorList[0x52F3] = {name = "Debug 3", unit = UNIT_RAW}
createSensorList[0x52F4] = {name = "Debug 4", unit = UNIT_RAW}
createSensorList[0x52F5] = {name = "Debug 5", unit = UNIT_RAW}
createSensorList[0x52F6] = {name = "Debug 6", unit = UNIT_RAW}
createSensorList[0x52F8] = {name = "Debug 7", unit = UNIT_RAW}

-- reserved for msp sensors
--[[
0x5FFF
0x5FFE
0x5FFD
0x5FFC
0x5FFB
0x5FFA
0x5FF9
0x5FF8
0x5FF7
0x5FF6
0x5FF5
0x5FF4
0x5FF3
0x5FF2
0x5FF1
0x5FF0
0x5FEF
0x5FEE
0x5FED
0x5FEC
0x5FEB
0x5FEA
0x5FE9
0x5FE8
0x5FE7
0x5FE6
0x5FE5
0x5FE4
0x5FE3
0x5FE2
]]--

-- rename
local renameSensorList = {}
renameSensorList[0x0500] = {name = "Headspeed", onlyifname = "RPM"}
renameSensorList[0x0501] = {name = "Tailspeed", onlyifname = "RPM"}

renameSensorList[0x0210] = {name = "Voltage", onlyifname = "VFAS"}

renameSensorList[0x0600] = {name = "Charge Level", onlyifname = "Fuel"}
renameSensorList[0x0910] = {name = "Cell Voltage", onlyifname = "ADC4"}

renameSensorList[0x0211] = {name = "ESC Voltage", onlyifname = "VFAS"}
renameSensorList[0x0B70] = {name = "ESC Temp", onlyifname = "ESC temp"}

renameSensorList[0x0218] = {name = "ESC1 Voltage", onlyifname = "VFAS"}
renameSensorList[0x0208] = {name = "ESC1 Current", onlyifname = "Current"}
renameSensorList[0x0508] = {name = "ESC1 RPM", onlyifname = "RPM"}
renameSensorList[0x0418] = {name = "ESC1 Temp", onlyifname = "Temp2"}

renameSensorList[0x0219] = {name = "BEC1 Voltage", onlyifname = "VFAS"}
renameSensorList[0x0229] = {name = "BEC1 Current", onlyifname = "Current"}
renameSensorList[0x0419] = {name = "BEC1 Temp", onlyifname = "Temp2"}

renameSensorList[0x021A] = {name = "ESC2 Voltage", onlyifname = "VFAS"}
renameSensorList[0x020A] = {name = "ESC2 Current", onlyifname = "Current"}
renameSensorList[0x050A] = {name = "ESC2 RPM", onlyifname = "RPM"}
renameSensorList[0x041A] = {name = "ESC2 Temp", onlyifname = "Temp2"}

renameSensorList[0x0840] = {name = "GPS Heading", onlyifname = "GPS course"}

renameSensorList[0x0900] = {name = "MCU Voltage", onlyifname = "ADC3"}
renameSensorList[0x0901] = {name = "BEC Voltage", onlyifname = "ADC3"}
renameSensorList[0x0902] = {name = "BUS Voltage", onlyifname = "ADC3"}

renameSensorList[0x0201] = {name = "ESC Current", onlyifname = "Current"}
renameSensorList[0x0222] = {name = "BEC Current", onlyifname = "Current"}

renameSensorList[0x0400] = {name = "MCU Temp", onlyifname = "Temp1"}
renameSensorList[0x0401] = {name = "ESC Temp", onlyifname = "Temp1"}
renameSensorList[0x0402] = {name = "BEC Temp", onlyifname = "Temp1"}

renameSensorList[0x5210] = {name = "Y.angle", onlyifname = "Heading"}

frsky.createSensorCache = {}
frsky.renameSensorCache = {}
frsky.dropSensorCache = {}

-- Track once-only ops to avoid repeated work
frsky.renamed = {}
frsky.dropped = {}


--[[
    createSensor - Creates a custom sensor if it doesn't already exist.

    @param physId (number) - The physical ID of the sensor.
    @param primId (number) - The primary ID of the sensor.
    @param appId (number) - The application ID of the sensor.
    @param frameValue (number) - The frame value of the sensor.

    This function checks if the API version is available and if the custom sensor
    specified by appId exists. If the sensor does not exist, it creates a new sensor
    with the specified parameters and caches it for future use.
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
    dropSensor - Drops a sensor based on the provided parameters if certain conditions are met.

    Parameters:
    physId (number) - The physical ID of the sensor.
    primId (number) - The primary ID of the sensor.
    appId (number) - The application ID of the sensor.
    frameValue (number) - The frame value of the sensor.

    Description:
    This function checks the API version and ensures it is found before proceeding. 
    It does not perform any sensor dropping if the API version is 12.08 or higher due to a new telemetry system.
    If the sensor is in the dropSensorList and not already cached, it retrieves the sensor source and drops it.
]]
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
    renameSensor - Renames a sensor based on provided parameters if certain conditions are met.

    Parameters:
    physId (number) - The physical ID of the sensor.
    primId (number) - The primary ID of the sensor.
    appId (number) - The application ID of the sensor.
    frameValue (number) - The frame value of the sensor.

    Description:
    This function checks if the API version is available and if the sensor with the given appId exists in the renameSensorList.
    If the sensor exists and is not already cached, it retrieves the sensor source and renames it if its current name matches the specified condition.
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
                 Only packets with a data ID within 0x5000 to 0x50FF (frame ID == 0x10) 
                 and packets with a frame ID equal to 0x32 (regardless of the data ID) 
                 are passed to the LUA telemetry receive queue.
    Returns: 
        - true if a frame was processed
        - false if no frame was available
    Notes: 
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
    frsky.wakeup()

    This function is responsible for managing the sensor caches and ensuring that they are cleared when necessary.
    It performs the following tasks:
    
    - Defines a local function `clearCaches` to clear the sensor caches.
    - Checks if the cache expiration time has been reached and clears the caches if necessary.
    - Flushes the sensor list if telemetry is inactive or the RSSI sensor is not available.
    - Ensures that the function does not run if the GUI is busy or the MSP queue is not processed.
]]
function frsky.wakeup()
    -- Bail early if telemetry is unavailable
    if not rfsuite.session.telemetryState or not rfsuite.session.telemetrySensor then
        frsky.reset()
        return
    end

    -- Safety: required task objects present?
    if not (rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue) then
        return
    end

    -- Drain only when GUI is idle and MSP queue is processed (your preferred gating)
    if rfsuite.app and rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then
        local discoverActive = (system and system.isSensorDiscoverActive and system.isSensorDiscoverActive() == true)

        if discoverActive then
            -- ETHOS discovery: unbounded drain for faster sensor discovery
            while telemetryPop() do end
        else
            -- Legacy: bounded, low CPU
            local start = os.clock()
            local count = 0
            while count < MAX_FRAMES_PER_WAKEUP and (os.clock() - start) <= MAX_TIME_BUDGET do
                if not telemetryPop() then break end
                count = count + 1
            end
        end
    end
end


function frsky.reset()
    frsky.createSensorCache = {}
    frsky.renameSensorCache = {}
    frsky.dropSensorCache = {}
    frsky.renamed = {}
    frsky.dropped = {}
end

return frsky
