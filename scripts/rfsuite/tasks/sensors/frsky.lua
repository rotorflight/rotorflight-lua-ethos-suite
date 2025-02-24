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
local cacheExpireTime = 10 -- Time in seconds to expire the caches
local lastCacheFlushTime = os.clock() -- Store the initial time

-- create
local createSensorList = {}
createSensorList[0x5100] = {name = "Heartbeat", unit = UNIT_RAW}
createSensorList[0x5250] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x5260] = {name = "Cell Count", unit = UNIT_RAW}
createSensorList[0x51A0] = {name = "Pitch Control", unit = UNIT_DEGREE, decimals = 2}
createSensorList[0x51A1] = {name = "Roll Control", unit = UNIT_DEGREE, decimals = 2}
createSensorList[0x51A2] = {name = "Yaw Control", unit = UNIT_DEGREE, decimals = 2}
createSensorList[0x51A3] = {name = "Collective Control", unit = UNIT_DEGREE, decimals = 2}
createSensorList[0x51A4] = {name = "Throttle %", unit = UNIT_PERCENT, decimals = 0}
createSensorList[0x5258] = {name = "ESC1 Capacity", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x5268] = {name = "ESC1 Power", unit = UNIT_PERCENT}
createSensorList[0x5269] = {name = "ESC1 Throttle", unit = UNIT_PERCENT}
createSensorList[0x525A] = {name = "ESC2 Capacity", unit = UNIT_MILLIAMPERE_HOUR}
createSensorList[0x51D0] = {name = "CPU Load", unit = UNIT_PERCENT}
createSensorList[0x51D1] = {name = "System Load", unit = UNIT_PERCENT}
createSensorList[0x51D2] = {name = "RT Load", unit = UNIT_PERCENT}
createSensorList[0x5120] = {name = "Model ID", unit = UNIT_RAW}
createSensorList[0x5121] = {name = "Flight Mode", unit = UNIT_RAW}
createSensorList[0x5122] = {name = "Arming Flags", unit = UNIT_RAW}
createSensorList[0x5123] = {name = "Arming Disable Flags", unit = UNIT_RAW}
createSensorList[0x5124] = {name = "Rescue State", unit = UNIT_RAW}
createSensorList[0x5125] = {name = "Governor State", unit = UNIT_RAW}
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

-- drop (drop sensors only runs if < msp 12.08)
local dropSensorList = {}
-- dropSensorList[0x0400] = {name = "Temp1"}

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

frsky.createSensorCache = {}
frsky.dropSensorCache = {}
frsky.renameSensorCache = {}

local function createSensor(physId, primId, appId, frameValue)

    -- we dont want any deletions if api has not been found
    if rfsuite.session.apiVersion == nil then return end

    -- check for custom sensors and create them if they dont exist
    if createSensorList[appId] ~= nil then

        local v = createSensorList[appId]

        if frsky.createSensorCache[appId] == nil then

            frsky.createSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.createSensorCache[appId] == nil then

                rfsuite.utils.log("Creating sensor: " .. v.name, "info")

                frsky.createSensorCache[appId] = model.createSensor()
                frsky.createSensorCache[appId]:name(v.name)
                frsky.createSensorCache[appId]:appId(appId)
                frsky.createSensorCache[appId]:physId(physId)
                frsky.createSensorCache[appId]:module(rfsuite.session.rssiSensor:module())

                frsky.createSensorCache[appId]:minimum(min or -1000000000)
                frsky.createSensorCache[appId]:maximum(max or 2147483647)
                if v.unit ~= nil then
                    frsky.createSensorCache[appId]:unit(v.unit)
                    frsky.createSensorCache[appId]:protocolUnit(v.unit)
                end
                if v.decimals ~= nil then
                    frsky.createSensorCache[appId]:decimals(v.decimals)
                    frsky.createSensorCache[appId]:protocolDecimals(v.decimals)
                end
                if v.minimum ~= nil then frsky.createSensorCache[appId]:minimum(v.minimum) end
                if v.maximum ~= nil then frsky.createSensorCache[appId]:maximum(v.maximum) end

            end

        end
    end

end

local function dropSensor(physId, primId, appId, frameValue)

    -- we dont want any deletions if api has not been found
    if rfsuite.session.apiVersion == nil then return end

    -- we do not do any sensor dropping post 12.08 as have new frsky telem system
    if rfsuite.session.apiVersion >= 12.08 then return end

    -- check for custom sensors and create them if they dont exist
    if dropSensorList[appId] ~= nil then
        local v = dropSensorList[appId]

        if frsky.dropSensorCache[appId] == nil then
            frsky.dropSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.dropSensorCache[appId] ~= nil then
                rfsuite.utils.log("Drop sensor: " .. v.name, "info")
                frsky.dropSensorCache[appId]:drop()
            end

        end

    end

end

local function renameSensor(physId, primId, appId, frameValue)

    -- we dont want any deletions if api has not been found
    if rfsuite.session.apiVersion == nil then return end

    -- check for custom sensors and create them if they dont exist
    if renameSensorList[appId] ~= nil then
        local v = renameSensorList[appId]

        if frsky.renameSensorCache[appId] == nil then
            frsky.renameSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.renameSensorCache[appId] ~= nil then
                if frsky.renameSensorCache[appId]:name() == v.onlyifname then
                    rfsuite.utils.log("Rename sensor: " .. v.name, "info")
                    frsky.renameSensorCache[appId]:name(v.name)
                end
            end

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

function frsky.wakeup()

    -- Function to clear caches
    local function clearCaches()
        frsky.createSensorCache = {}
        frsky.renameSensorCache = {}
        frsky.dropSensorCache = {}
    end

    -- Check if it's time to expire the caches
    if os.clock() - lastCacheFlushTime >= cacheExpireTime then
        clearCaches()
        lastCacheFlushTime = os.clock() -- Reset the timer
    end

    -- Flush sensor list if we kill the sensors
    if not rfsuite.tasks.telemetry.active() or not rfsuite.session.rssiSensor then clearCaches() end

    -- If GUI or queue is busy.. do not do this!
    if rfsuite.tasks and rfsuite.tasks.telemetry and rfsuite.tasks.telemetry.active() and rfsuite.session.rssiSensor then if rfsuite.app.guiIsRunning == false and rfsuite.tasks.msp.mspQueue:isProcessed() then while telemetryPop() do end end end

end

return frsky
