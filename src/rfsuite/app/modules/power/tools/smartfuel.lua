--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local lastFblMode = nil
local useFirmwareSmartFuel = rfsuite.utils.apiVersionCompare(">=", {12, 0, 9})

-- Source field differs between firmware versions
local sourceField = useFirmwareSmartFuel
    and {t = "@i18n(sensors.smartfuel)@", mspapi = 1, apikey = "smartfuel",        type = 1}
    or  {t = "@i18n(sensors.smartfuel)@", mspapi = 1, apikey = "smartfuel_source", type = 1}

-- Firmware path (>= 12.9): simple ON/OFF, 3 FBL algorithm params (no stabilize/stable window)
-- Legacy path (< 12.9):    Current/Voltage, 5 params including stabilize and stable window
local firmwareFields = {
    sourceField,
    {t = "@i18n(app.modules.power.smartfuel_sag_compensation)@",   mspapi = 1, apikey = "smartfuel_sag_multiplier"},
    {t = "@i18n(app.modules.power.smartfuel_voltage_fall_limit)@", mspapi = 1, apikey = "smartfuel_voltage_fall_rate"},
    {t = "@i18n(app.modules.power.smartfuel_fuel_drop_rate)@",     mspapi = 1, apikey = "smartfuel_charge_drop_rate"},
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
        fields = useFirmwareSmartFuel and firmwareFields or legacyFields,
    }
}

-- First index of conditionally-shown tuning fields.
-- Firmware: fields 2-4 shown when FBL is ON (smartfuel = 1).
-- Legacy: fields 4-6 shown when Voltage mode is selected (source = 1).
local tuningFieldStart = useFirmwareSmartFuel and 2 or 4

local function getFblMode()
    local src = tonumber(sourceField.value) or 0
    return src == 1
end

local function postLoad(self)
    if useFirmwareSmartFuel then
        rfsuite.session = rfsuite.session or {}
        rfsuite.session.batteryConfig = rfsuite.session.batteryConfig or {}
        rfsuite.session.batteryConfig.smartfuel = tonumber(sourceField.value) or 0
    end
    lastFblMode = nil
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function postSave(self)
    if useFirmwareSmartFuel then
        rfsuite.session = rfsuite.session or {}
        rfsuite.session.batteryConfig = rfsuite.session.batteryConfig or {}
        rfsuite.session.batteryConfig.smartfuel = tonumber(sourceField.value) or 0
    end
    if rfsuite.tasks and rfsuite.tasks.sensors and type(rfsuite.tasks.sensors.resetSmart) == "function" then
        rfsuite.tasks.sensors.resetSmart()
    end
end

local function wakeup(self)
    if not enableWakeup then return end

    local fblMode = getFblMode()
    if fblMode == lastFblMode then return end
    lastFblMode = fblMode

    -- Enable/disable the algorithm tuning fields based on mode selection
    for i = tuningFieldStart, #apidata.formdata.fields do
        local fieldHandle = rfsuite.app.formFields[i]
        if not fieldHandle or not fieldHandle.enable then break end
        fieldHandle:enable(fblMode)
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
