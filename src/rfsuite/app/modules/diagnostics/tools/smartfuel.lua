--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local app = rfsuite.app
local tasks = rfsuite.tasks
local session = rfsuite.session
local system_getSource = system.getSource
local os_clock = os.clock
local math_floor = math.floor
local math_max = math.max

local enableWakeup = false
local lastWakeup = 0
local onNavMenu
local firmwareConfig
local firmwareReadStarted = false
local updateValues

local screenW = lcd.getWindowSize()
local valueX = math_max(120, math_floor(screenW * 0.28))
local valuePos = {x = valueX, y = app.radio.linePaddingTop, w = screenW - valueX - 8, h = app.radio.navbuttonHeight}

local fields = {}

local SOURCE_LABELS = {
    [0] = "OFF",
    [1] = "VOLTAGE",
    [2] = "CURRENT",
    [3] = "COMBINED",
}

local LOCAL_SOURCE_LABELS = {
    [0] = "CURRENT",
    [1] = "VOLTAGE",
}

local SENSOR_MAP = {
    sport = {
        protocol = "FBus / S.Port",
        fuel = {label = "0x0600", query = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600}, unit = "%"},
        consumption = {label = "0x5250", query = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250}, unit = "mAh"},
    },
    crsf = {
        protocol = "CRSF / ELRS",
        fuel = {label = "0x1014", query = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014}, unit = "%"},
        consumption = {label = "0x1013", query = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013}, unit = "mAh"},
    },
}

local SMART_SENSORS = {
    fuel = {label = "0x5FE1", query = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1}, unit = "%"},
    consumption = {label = "0x5FE0", query = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0}, unit = "mAh"},
}

local function getProtocol()
    return tasks and tasks.msp and tasks.msp.protocol and tasks.msp.protocol.mspProtocol
end

local function getBatteryPrefs()
    return session and session.modelPreferences and session.modelPreferences.battery or nil
end

local function getLocalSource()
    local prefs = getBatteryPrefs()
    if not prefs then return 0 end
    local source = tonumber(prefs.smartfuel_source)
    if source ~= nil then return source end
    return tonumber(prefs.calc_local) or 0
end

local function getFirmwareSource()
    if firmwareConfig and firmwareConfig.mode ~= nil then
        return firmwareConfig.mode
    end

    local bc = session and session.batteryConfig
    if not (bc and rfsuite.utils.apiVersionCompare(">=", {12, 0, 9})) then return nil end
    return tonumber(bc.smartfuelRemoteSource) or 0
end

local function getMode()
    local firmwareSource = getFirmwareSource()
    if firmwareSource and firmwareSource > 0 then
        return "Firmware " .. (SOURCE_LABELS[firmwareSource] or tostring(firmwareSource))
    end

    local localSource = getLocalSource()
    return "Local " .. (LOCAL_SOURCE_LABELS[localSource] or tostring(localSource))
end

local function getModeDetail()
    local firmwareSource = getFirmwareSource()
    local firmwareText = firmwareSource == nil and "n/a" or (SOURCE_LABELS[firmwareSource] or tostring(firmwareSource))
    local localSource = getLocalSource()
    local localText = LOCAL_SOURCE_LABELS[localSource] or tostring(localSource)
    return "FBL " .. firmwareText .. " / Local " .. localText
end

local function sourceValue(sourceDef)
    if not sourceDef then return nil, false end
    local source = system_getSource(sourceDef.query)
    if not source or (source.state and source:state() == false) then return nil, false end
    return source:value(), true
end

local function formatNumber(value, decimals)
    if value == nil then return "-" end
    local d = decimals or 0
    if d <= 0 then return tostring(math_floor(value + 0.5)) end
    local scale = 10 ^ d
    return string.format("%." .. tostring(d) .. "f", math_floor(value * scale + 0.5) / scale)
end

local function formatSensor(sourceDef)
    if not sourceDef then return "n/a" end
    local value, present = sourceValue(sourceDef)
    if not present then return sourceDef.label .. " -> -" end
    return sourceDef.label .. " -> " .. formatNumber(value, 0) .. (sourceDef.unit and (" " .. sourceDef.unit) or "")
end

local function setField(key, value, color)
    local field = fields[key]
    if not field then return end
    field:value(value or "-")
    if color then field:color(color) end
end

local function readFirmwareConfig()
    if firmwareReadStarted then return end
    if not (rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) and tasks and tasks.msp and tasks.msp.api) then return end
    firmwareReadStarted = true

    local api = tasks.msp.api.load("SMARTFUEL_CONFIG")
    api.setCompleteHandler(function()
        firmwareConfig = {
            mode = tonumber(api.readValue("smartfuel_mode")) or 0,
            voltageDropRate = tonumber(api.readValue("voltage_drop_rate")),
            chargeDropRate = tonumber(api.readValue("charge_drop_rate")),
            sagGain = tonumber(api.readValue("sag_gain")),
        }
        updateValues()
    end)
    api.setErrorHandler(function()
        firmwareConfig = nil
    end)
    api.setUUID("diagnostics-smartfuel-config")
    api.read()
end

local function addLine(key, label, initial)
    app.formLines[app.formLineCnt] = form.addLine(label)
    fields[key] = form.addStaticText(app.formLines[app.formLineCnt], valuePos, initial or "-")
    app.formLineCnt = app.formLineCnt + 1
end

updateValues = function()
    local protocolKey = getProtocol()
    local protocol = SENSOR_MAP[protocolKey]
    local protocolText = protocol and protocol.protocol or tostring(protocolKey or "Unknown")

    setField("protocol", protocolText)
    setField("mode", getMode())
    setField("mode_detail", getModeDetail())

    setField("source_fuel", formatSensor(protocol and protocol.fuel))
    setField("source_consumption", formatSensor(protocol and protocol.consumption))
    setField("dest_fuel", formatSensor(SMART_SENSORS.fuel))
    setField("dest_consumption", formatSensor(SMART_SENSORS.consumption))

    local prefs = getBatteryPrefs() or {}
    local bc = session and session.batteryConfig or {}
    local voltageDrop = (firmwareConfig and firmwareConfig.voltageDropRate) or tonumber(prefs.voltage_drop_rate) or 10
    local chargeDrop = (firmwareConfig and firmwareConfig.chargeDropRate) or tonumber(prefs.charge_drop_rate) or 50
    local sagGain = (firmwareConfig and firmwareConfig.sagGain) or tonumber(prefs.sag_gain) or 40
    local capacity = tonumber(bc.batteryCapacity) or 0
    local reserve = tonumber(bc.consumptionWarningPercentage) or 0

    if chargeDrop > 250 then chargeDrop = chargeDrop / 100 end

    setField("tuning_source", firmwareConfig and "Firmware MSP" or "Local preferences")
    setField("voltage_slew", formatNumber(voltageDrop, 0) .. " mV/s")
    setField("charge_slew", formatNumber(chargeDrop / 100, 2) .. " %/s")
    setField("sag_gain", formatNumber(sagGain, 0) .. "%")
    setField("capacity", formatNumber(capacity, 0) .. " mAh")
    setField("reserve", formatNumber(reserve, 0) .. "%")
end

local function openPage(opts)
    enableWakeup = false
    app.triggers.closeProgressLoader = true
    form.clear()

    app.lastIdx = opts.idx
    app.lastTitle = opts.title
    app.lastScript = opts.script

    app.ui.fieldHeader("@i18n(app.modules.diagnostics.name)@" .. " / " .. "@i18n(app.modules.power.smartfuel_name)@")

    app.formLineCnt = 0
    app.formFieldCount = 0
    fields = {}
    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end

    addLine("protocol", "Protocol")
    addLine("mode", "Active mode")
    addLine("mode_detail", "Mode sources")
    addLine("tuning_source", "Tuning source")
    addLine("source_fuel", "Source fuel")
    addLine("source_consumption", "Source consumption")
    addLine("dest_fuel", "Smart Fuel")
    addLine("dest_consumption", "Smart Consumption")
    addLine("voltage_slew", "Voltage slew")
    addLine("charge_slew", "Charge slew")
    addLine("sag_gain", "Sag gain")
    addLine("capacity", "Pack capacity")
    addLine("reserve", "Reserve alert")

    readFirmwareConfig()
    updateValues()
    enableWakeup = true
end

local function wakeup()
    if not enableWakeup then return end
    local now = os_clock()
    if (now - lastWakeup) < 0.5 then return end
    lastWakeup = now
    updateValues()
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

onNavMenu = function()
    pageRuntime.openMenuContext()
    return true
end

return {reboot = false, eepromWrite = false, minBytes = 0, wakeup = wakeup, refreshswitch = false, simulatorResponse = {}, openPage = openPage, onNavMenu = onNavMenu, event = event, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}, API = {}}
