--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local lastVoltageMode = nil
local useFirmwareSmartFuel = rfsuite.utils.apiVersionCompare(">=", {12, 0, 9})

-- Field index 1: source selector (different field/API per version)
-- Fields 2-6: voltage-algorithm tuning params (always mspapi=1)
local sourceField = useFirmwareSmartFuel
    and {t = "@i18n(sensors.smartfuel)@", mspapi = 1, apikey = "smartfuel_remote_source", type = 1}
    or  {t = "@i18n(sensors.smartfuel)@", mspapi = 1, apikey = "smartfuel_source",        type = 1}

local apidata = {
    api = useFirmwareSmartFuel
        and {[1] = "SMARTFUEL_CONFIG"}
        or  {[1] = "BATTERY_INI"},
    formdata = {
        labels = {},
        fields = {
            sourceField,
            {t = "@i18n(app.modules.power.smartfuel_stabilize_delay)@",    mspapi = 1, apikey = "stabilize_delay"},
            {t = "@i18n(app.modules.power.smartfuel_stable_window)@",      mspapi = 1, apikey = "stable_window"},
            {t = "@i18n(app.modules.power.smartfuel_sag_compensation)@",   mspapi = 1, apikey = "sag_multiplier_percent"},
            {t = "@i18n(app.modules.power.smartfuel_voltage_fall_limit)@", mspapi = 1, apikey = "voltage_fall_limit"},
            {t = "@i18n(app.modules.power.smartfuel_fuel_drop_rate)@",     mspapi = 1, apikey = "fuel_drop_rate"},
        }
    }
}

local function getVoltageMode()
    local src = tonumber(sourceField.value) or 0
    if useFirmwareSmartFuel then
        -- OFF(0)=local Smart Fuel, CURRENT(1)=firmware current, VOLTAGE(2)=firmware voltage
        return src == 0
    else
        -- Current Sensor(0), Voltage Sensor(1)
        return src == 1
    end
end

local function postLoad(self)
    if useFirmwareSmartFuel then
        rfsuite.session = rfsuite.session or {}
        rfsuite.session.batteryConfig = rfsuite.session.batteryConfig or {}
        rfsuite.session.batteryConfig.smartfuelRemoteSource = tonumber(sourceField.value) or 0
    end
    lastVoltageMode = nil
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

    local voltageMode = getVoltageMode()
    if voltageMode == lastVoltageMode then return end
    lastVoltageMode = voltageMode

    -- Fields 1-3 always active (source, stabilize_delay, stable_window)
    -- Fields 4-6 are voltage-specific (sag_multiplier_percent, voltage_fall_limit, fuel_drop_rate)
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
