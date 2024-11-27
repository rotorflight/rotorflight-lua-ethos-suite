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

]]--
local arg = {...}
local config = arg[1]

local frsky = {}

-- Sensor lists (combined into one table with type markers)
local sensorLists = {
    create = {
        [0x5450] = {name = "Governor", unit = UNIT_RAW},
        [0x5110] = {name = "Adj. Source", unit = UNIT_RAW},
        [0x5111] = {name = "Adj. Value", unit = UNIT_RAW},
        [0x5460] = {name = "Model ID", unit = UNIT_RAW},
        [0x5471] = {name = "PID Profile", unit = UNIT_RAW},
        [0x5472] = {name = "Rate Profile", unit = UNIT_RAW},
        [0x5440] = {name = "Throttle %", unit = UNIT_PERCENT},
        [0x5250] = {name = "Consumption", unit = UNIT_MILLIAMPERE_HOUR},
        [0x5462] = {name = "Arming Flags", unit = UNIT_RAW}
    },
    drop = {
        [0x0400] = {name = "Temp1"},
        [0x0410] = {name = "Temp1"}
    },
    rename = {
        [0x0500] = {name = "Headspeed", onlyifname = "RPM"},
        [0x0501] = {name = "Tailspeed", onlyifname = "RPM"},
        [0x0210] = {name = "Voltage", onlyifname = "VFAS"},
        [0x0200] = {name = "Current", onlyifname = "Current"},
        [0x0600] = {name = "Charge Level", onlyifname = "Fuel"},
        [0x0910] = {name = "Cell Voltage", onlyifname = "ADC4"},
        [0x0900] = {name = "BEC Voltage", onlyifname = "ADC3"},
        [0x0211] = {name = "ESC Voltage", onlyifname = "VFAS"},
        [0x0201] = {name = "ESC Current", onlyifname = "Current"},
        [0x0502] = {name = "ESC RPM", onlyifname = "RPM"},
        [0x0B70] = {name = "ESC Temp", onlyifname = "ESC temp"},
        [0x0212] = {name = "ESC2 Voltage", onlyifname = "VFAS"},
        [0x0202] = {name = "ESC2 Current", onlyifname = "Current"},
        [0x0503] = {name = "ESC2 RPM", onlyifname = "RPM"},
        [0x0B71] = {name = "ESC2 Temp", onlyifname = "ESC temp"},
        [0x0401] = {name = "MCU Temp", onlyifname = "Temp1"},
        [0x0840] = {name = "Heading", onlyifname = "GPS course"}
    }
}

-- Cache tables for sensors
frsky.createSensorCache = {}
frsky.dropSensorCache = {}
frsky.renameSensorCache = {}

-- Common function for handling sensor creation, dropping, and renaming
local function handleSensorAction(sensorList, cacheTable, actionType, physId, primId, appId, frameValue)
    local sensorData = sensorList[appId]
    if sensorData and cacheTable[appId] == nil then
        cacheTable[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        if not cacheTable[appId] then
            --print(actionType .. " sensor: " .. sensorData.name)
            if actionType == "Create" then
                cacheTable[appId] = model.createSensor()
                cacheTable[appId]:name(sensorData.name)
                cacheTable[appId]:appId(appId)
                cacheTable[appId]:physId(physId)
                cacheTable[appId]:module(rfsuite.rssiSensor:module())
                cacheTable[appId]:unit(sensorData.unit or UNIT_RAW)
            elseif cacheTable[appId] ~= nil and actionType == "Drop" then
                    cacheTable[appId]:drop()
            elseif cacheTable[appId] ~= nil and actionType == "Rename" and cacheTable[appId]:name() == sensorData.onlyifname then
                    cacheTable[appId]:name(sensorData.name)
            end
        end
    end
end

-- Sensor processing functions
local function createSensor(physId, primId, appId, frameValue)
    handleSensorAction(sensorLists.create, frsky.createSensorCache, "Create", physId, primId, appId, frameValue)
end

local function dropSensor(physId, primId, appId, frameValue)
    handleSensorAction(sensorLists.drop, frsky.dropSensorCache, "Drop", physId, primId, appId, frameValue)
end

local function renameSensor(physId, primId, appId, frameValue)
    handleSensorAction(sensorLists.rename, frsky.renameSensorCache, "Rename", physId, primId, appId, frameValue)
end

local function telemetryPop()
    
    if rfsuite.app.triggers.mspBusy then return end

    local frame = rfsuite.bg.msp.sensor:popFrame()
    if frame == nil then return false end
    if not frame.physId or not frame.primId then return end

    createSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    dropSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    renameSensor(frame:physId(), frame:primId(), frame:appId(), frame:value())
    return true
end

-- Wakeup function
function frsky.wakeup()
    if not rfsuite.bg.telemetry.active() or not rfsuite.rssiSensor then
        frsky.createSensorCache = {}
        frsky.renameSensorCache = {}
        frsky.dropSensorCache = {}
    end

    if rfsuite.bg and rfsuite.bg.telemetry and rfsuite.bg.telemetry.active() and rfsuite.rssiSensor then
        if not rfsuite.app.guiIsRunning and rfsuite.bg.msp.mspQueue:isProcessed() then
            while telemetryPop() do end
        end
    end
end

return frsky