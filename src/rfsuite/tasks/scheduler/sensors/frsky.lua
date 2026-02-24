--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local os_clock = os.clock
local system_getSource = system.getSource
local model_createSensor = model.createSensor
local load_file = loadfile

local frsky = {}
local cacheExpireTime = 30
local lastCacheFlushTime = os_clock()
local sensorTlm = nil

frsky.name = "frsky"
frsky._provisioned = false
frsky.createSensorCache = {}
frsky.renameSensorCache = {}
frsky.dropSensorCache = {}

local function loadSidLookup()
    local lookupLoader, lookupErr = load_file("tasks/scheduler/sensors/frsky_sid_lookup.lua")
    if not lookupLoader then
        if rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("[frsky] Failed to load SID lookup table: " .. tostring(lookupErr), "error") end
        return {}
    end

    local lookupTable = lookupLoader()
    if type(lookupTable) ~= "table" then
        if rfsuite.utils and rfsuite.utils.log then rfsuite.utils.log("[frsky] SID lookup file did not return a table", "error") end
        return {}
    end

    return lookupTable
end

local sidLookup = loadSidLookup()

-- MSP Sensors start at 0x5FFF.  We use lower values for FrSky S.Port sensors to avoid conflicts.
-- Custom Frsky sensors can use 0x5100 to 0x5FFE range.
-- Check msp.lua for MSP sensor definitions.

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
-- no higher than 0x5FFE

local log = rfsuite.utils.log

local dropSensorList = {}

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
frsky.dropSensorCache = {}
frsky.renameSensorCache = {}

local function createSensor(physId, primId, appId, frameValue)

    if rfsuite.session.apiVersion == nil then return end

    if createSensorList[appId] ~= nil then

        local v = createSensorList[appId]

        if frsky.createSensorCache[appId] == nil then

            frsky.createSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.createSensorCache[appId] == nil then

                log("Creating sensor: " .. v.name, "info")

                frsky.createSensorCache[appId] = model_createSensor()
                frsky.createSensorCache[appId]:name(v.name)
                frsky.createSensorCache[appId]:type(SENSOR_TYPE_SPORT)
                frsky.createSensorCache[appId]:appId(appId)
                frsky.createSensorCache[appId]:physId(physId)
                frsky.createSensorCache[appId]:module(rfsuite.session.telemetrySensor:module())

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

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.utils.apiVersionCompare(">=", {12, 0, 8}) then return end

    if dropSensorList[appId] ~= nil then
        local v = dropSensorList[appId]

        if frsky.dropSensorCache[appId] == nil then
            frsky.dropSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.dropSensorCache[appId] ~= nil then
                log("Drop sensor: " .. v.name, "info")
                frsky.dropSensorCache[appId]:drop()
            end

        end

    end

end

local function renameSensor(physId, primId, appId, frameValue)

    if rfsuite.session.apiVersion == nil then return end

    if renameSensorList[appId] ~= nil then
        local v = renameSensorList[appId]

        if frsky.renameSensorCache[appId] == nil then
            frsky.renameSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.renameSensorCache[appId] ~= nil then
                if frsky.renameSensorCache[appId]:name() == v.onlyifname then
                    log("Rename sensor: " .. v.name, "info")
                    frsky.renameSensorCache[appId]:name(v.name)
                end
            end

        end

    end

end

local function ensureSensorsFromConfig()

    if frsky._provisioned then return end

    local cfg = rfsuite and rfsuite.session and rfsuite.session.telemetryConfig
    if not cfg then return end

    local telePhysId, teleModule
    if sensorTlm then
        telePhysId = 27
        teleModule = sensorTlm:module()
    else
        return
    end

    for _, sid in ipairs(cfg) do
        local apps = sidLookup[sid]
        if apps then
            for _, appId in ipairs(apps) do
                if appId then

                    local meta = createSensorList[appId]
                    if meta then
                        if frsky.createSensorCache[appId] == nil then frsky.createSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId}) end
                        if frsky.createSensorCache[appId] == nil then
                            log("Creating sensor: " .. meta.name, "info")
                            local s = model_createSensor()
                            s:name(meta.name)
                            s:appId(appId)
                            if telePhysId then s:physId(telePhysId) end
                            if teleModule then s:module(teleModule) end

                            s:minimum(-1000000000)
                            s:maximum(2147483647)
                            if meta.unit ~= nil then
                                s:unit(meta.unit)
                                s:protocolUnit(meta.unit)
                            end
                            if meta.decimals ~= nil then
                                s:decimals(meta.decimals)
                                s:protocolDecimals(meta.decimals)
                            end
                            if meta.minimum ~= nil then s:minimum(meta.minimum) end
                            if meta.maximum ~= nil then s:maximum(meta.maximum) end
                            frsky.createSensorCache[appId] = s
                        end
                    end

                    local rn = renameSensorList[appId]
                    if rn then
                        if frsky.renameSensorCache[appId] == nil then frsky.renameSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId}) end
                        local src = frsky.renameSensorCache[appId]
                        if src and src:name() == rn.onlyifname then
                            log("Rename sensor: " .. rn.name, "info")
                            src:name(rn.name)
                        end
                    end

                    if rfsuite.session.apiVersion ~= nil and rfsuite.utils.apiVersionCompare("<", {12, 0, 8}) then
                        local drop = dropSensorList[appId]
                        if drop then
                            if frsky.dropSensorCache[appId] == nil then frsky.dropSensorCache[appId] = system_getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId}) end
                            local src = frsky.dropSensorCache[appId]
                            if src then
                                log("Drop sensor: " .. drop.name, "info")
                                src:drop()
                                frsky.dropSensorCache[appId] = nil
                            end
                        end
                    end

                end
            end
        end
    end
    frsky._provisioned = true
end

local function clearCaches()
    frsky.createSensorCache = {}
    frsky.renameSensorCache = {}
    frsky.dropSensorCache = {}
end

function frsky.wakeup()

    if not rfsuite.session.isConnected then return end

    if not sensorTlm then
        sensorTlm = sport.getSensor()
        sensorTlm:module(rfsuite.session.telemetrySensor:module())

        if not sensorTlm then return false end
    end

    if os_clock() - lastCacheFlushTime >= cacheExpireTime then
        clearCaches()
        lastCacheFlushTime = os_clock()
    end

    if not rfsuite.session.telemetryState or not rfsuite.session.telemetrySensor then clearCaches() end

    -- if this function exists, we can use it to determine if we should quick exit and avoid all sensor popping
    if system.isSensorDiscoverActive then 
        if system.isSensorDiscoverActive() then
            return
        end
    end

    ensureSensorsFromConfig()

end

function frsky.reset()
    frsky.createSensorCache = {}
    frsky.dropSensorCache = {}
    frsky.renameSensorCache = {}
    frsky._provisioned = false
end

return frsky
