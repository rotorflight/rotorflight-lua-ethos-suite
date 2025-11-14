--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local frsky = {}
local cacheExpireTime = 30
local lastCacheFlushTime = os.clock()
local sensorTlm = nil

frsky.name = "frsky"
frsky._provisioned = false
frsky.createSensorCache = {}
frsky.renameSensorCache = {}
frsky.dropSensorCache = {}

local sidLookup = {
    [1] = {'0x5100'},
    [3] = {'0x0210'},
    [4] = {'0x0200'},
    [5] = {'0x5250'},
    [6] = {'0x0600'},
    [7] = {'0x5260'},
    [8] = {'0x0910'},
    [11] = {'0x51A0'},
    [12] = {'0x51A1'},
    [13] = {'0x51A2'},
    [14] = {'0x51A3'},
    [15] = {'0x51A4'},
    [17] = {'0x0218'},
    [18] = {'0x0208'},
    [19] = {'0x5258'},
    [20] = {'0x0508'},
    [21] = {'0x5268'},
    [22] = {'0x5269'},
    [23] = {'0x0418'},
    [24] = {'0x0419'},
    [25] = {'0x0219'},
    [26] = {'0x0229'},
    [27] = {'0x5128'},
    [28] = {'0x5129'},
    [30] = {'0x021A'},
    [31] = {'0x020A'},
    [32] = {'0x525A'},
    [33] = {'0x050A'},
    [36] = {'0x041A'},
    [41] = {'0x512B'},
    [42] = {'0x0211'},
    [43] = {'0x0901'},
    [44] = {'0x0902'},
    [45] = {'0x0900'},
    [46] = {'0x0201'},
    [47] = {'0x0222'},
    [50] = {'0x0401'},
    [51] = {'0x0402'},
    [52] = {'0x0400'},
    [57] = {'0x5210'},
    [58] = {'0x0100'},
    [59] = {'0x0110'},
    [60] = {'0x0500'},
    [61] = {'0x0501'},
    [65] = {'0x0730'},
    [66] = {'0x0730'},
    [69] = {'0x0700'},
    [70] = {'0x0710'},
    [71] = {'0x0720'},
    [77] = {'0x0800'},
    [78] = {'0x0820'},
    [79] = {'0x0840'},
    [80] = {'0x0830'},
    [85] = {'0x51D0'},
    [86] = {'0x51D1'},
    [87] = {'0x51D2'},
    [88] = {'0x5120'},
    [89] = {'0x5121'},
    [90] = {'0x5122'},
    [91] = {'0x5123'},
    [92] = {'0x5124'},
    [93] = {'0x5125'},
    [95] = {'0x5130'},
    [96] = {'0x5131'},
    [99] = {'0x5110', '0x5111'}
}

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

            frsky.createSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

            if frsky.createSensorCache[appId] == nil then

                log("Creating sensor: " .. v.name, "info")

                frsky.createSensorCache[appId] = model.createSensor()
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

    if rfsuite.session.apiVersion >= 12.08 then return end

    if dropSensorList[appId] ~= nil then
        local v = dropSensorList[appId]

        if frsky.dropSensorCache[appId] == nil then
            frsky.dropSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

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
            frsky.renameSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})

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
            for _, hex in ipairs(apps) do
                local appId = tonumber(hex)
                if appId then

                    local meta = createSensorList[appId]
                    if meta then
                        if frsky.createSensorCache[appId] == nil then frsky.createSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId}) end
                        if frsky.createSensorCache[appId] == nil then
                            log("Creating sensor: " .. meta.name, "info")
                            local s = model.createSensor()
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
                        if frsky.renameSensorCache[appId] == nil then frsky.renameSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId}) end
                        local src = frsky.renameSensorCache[appId]
                        if src and src:name() == rn.onlyifname then
                            log("Rename sensor: " .. rn.name, "info")
                            src:name(rn.name)
                        end
                    end

                    if rfsuite.session.apiVersion ~= nil and rfsuite.session.apiVersion < 12.08 then
                        local drop = dropSensorList[appId]
                        if drop then
                            if frsky.dropSensorCache[appId] == nil then frsky.dropSensorCache[appId] = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId}) end
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

function frsky.wakeup()

    if not rfsuite.session.isConnected then return end
    if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then return end

    if not sensorTlm then
        sensorTlm = sport.getSensor()
        sensorTlm:module(rfsuite.session.telemetrySensor:module())

        if not sensorTlm then return false end
    end

    local function clearCaches()
        frsky.createSensorCache = {}
        frsky.renameSensorCache = {}
        frsky.dropSensorCache = {}
    end

    if os.clock() - lastCacheFlushTime >= cacheExpireTime then
        clearCaches()
        lastCacheFlushTime = os.clock()
    end

    if not rfsuite.session.telemetryState or not rfsuite.session.telemetrySensor then clearCaches() end

    ensureSensorsFromConfig()

end

function frsky.reset()
    frsky.createSensorCache = {}
    frsky.dropSensorCache = {}
    frsky.renameSensorCache = {}
    frsky._provisioned = false
end

return frsky
