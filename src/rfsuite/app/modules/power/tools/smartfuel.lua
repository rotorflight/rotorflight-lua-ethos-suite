--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local lastTuningActive = nil
local useFirmwareSmartFuel = rfsuite.utils.apiVersionCompare(">=", {12, 0, 9})

-- Field index 1: source selector (different field/API per version)
local sourceField = useFirmwareSmartFuel
    and {t = "@i18n(sensors.smartfuel)@", mspapi = 1, apikey = "smartfuel_mode", type = 1}
    or  {t = "@i18n(sensors.smartfuel)@", mspapi = 1, apikey = "smartfuel_source",        type = 1}

local firmwareFields = {
    sourceField,
    {t = "@i18n(app.modules.power.smartfuel_voltage_drop_rate)@", mspapi = 1, apikey = "voltage_drop_rate"},
    {t = "@i18n(app.modules.power.smartfuel_charge_drop_rate)@",  mspapi = 1, apikey = "charge_drop_rate"},
    {t = "@i18n(app.modules.power.smartfuel_sag_gain)@",          mspapi = 1, apikey = "sag_gain"},
}

local legacyFields = {
    sourceField,
    {t = "@i18n(app.modules.power.smartfuel_stabilize_delay)@",    mspapi = 1, apikey = "stabilize_delay"},
    {t = "@i18n(app.modules.power.smartfuel_stable_window)@",      mspapi = 1, apikey = "stable_window"},
    {t = "@i18n(app.modules.power.smartfuel_sag_compensation)@",   mspapi = 1, apikey = "sag_multiplier_percent"},
    {t = "@i18n(app.modules.power.smartfuel_voltage_fall_limit)@", mspapi = 1, apikey = "voltage_fall_limit"},
    {t = "@i18n(app.modules.power.smartfuel_fuel_drop_rate)@",     mspapi = 1, apikey = "fuel_drop_rate"},
}

local apidata = {
    api = useFirmwareSmartFuel
        and {[1] = "SMARTFUEL_CONFIG"}
        or  {[1] = "BATTERY_INI"},
    formdata = {
        labels = {},
        fields = useFirmwareSmartFuel and firmwareFields or legacyFields
    }
}

local function getVoltageMode()
    local src = tonumber(sourceField.value) or 0
    if useFirmwareSmartFuel then
        -- mode: 0=OFF, 1=VOLTAGE, 2=CURRENT
        return src == 1
    else
        -- Legacy: 0=Current Sensor, 1=Voltage Sensor
        return src == 1
    end
end

local function isTuningActive()
    local src = tonumber(sourceField.value) or 0
    if useFirmwareSmartFuel then
        -- mode: 0=OFF, 1=VOLTAGE, 2=CURRENT
        return src == 1
    end
    return src ~= 0
end

local function postLoad(self)
    if useFirmwareSmartFuel then
        rfsuite.session = rfsuite.session or {}
        rfsuite.session.batteryConfig = rfsuite.session.batteryConfig or {}
        rfsuite.session.batteryConfig.smartfuelRemoteSource = tonumber(sourceField.value) or 0
    end
    lastTuningActive = nil
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function postSave(self)
    if useFirmwareSmartFuel then
        rfsuite.session = rfsuite.session or {}
        rfsuite.session.batteryConfig = rfsuite.session.batteryConfig or {}
        rfsuite.session.batteryConfig.smartfuelRemoteSource = tonumber(sourceField.value) or 0
    end
    if rfsuite.tasks and rfsuite.tasks.sensors and type(rfsuite.tasks.sensors.resetSmart) == "function" then
        rfsuite.tasks.sensors.resetSmart()
    end
end

local function wakeup(self)
    if not enableWakeup then return end

    local tuningActive = isTuningActive()

    if tuningActive == lastTuningActive then return end
    lastTuningActive = tuningActive

    if useFirmwareSmartFuel then
        for i = 2, #apidata.formdata.fields do
            local fieldHandle = rfsuite.app.formFields[i]
            if not fieldHandle or not fieldHandle.enable then break end
            fieldHandle:enable(tuningActive)
        end
        return
    end

    for i = 2, 3 do
        local fieldHandle = rfsuite.app.formFields[i]
        if fieldHandle and fieldHandle.enable then
            fieldHandle:enable(true)
        end
    end

    local voltageMode = getVoltageMode()
    for i = 4, #apidata.formdata.fields do
        local fieldHandle = rfsuite.app.formFields[i]
        if not fieldHandle or not fieldHandle.enable then break end
        fieldHandle:enable(voltageMode)
    end
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

onNavMenu = function(self)
    pageRuntime.openMenuContext({defaultSection = "hardware"})
    return true
end

return {wakeup = wakeup, apidata = apidata, eepromWrite = true, reboot = false, API = {}, postLoad = postLoad, postSave = postSave, event = event, onNavMenu = onNavMenu}
