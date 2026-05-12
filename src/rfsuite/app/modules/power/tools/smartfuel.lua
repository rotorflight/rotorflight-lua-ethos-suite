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
    {t = "@i18n(app.modules.power.smartfuel_voltage_drop_rate)@", mspapi = 1, apikey = "voltage_drop_rate"},
    {t = "@i18n(app.modules.power.smartfuel_charge_drop_rate)@",  mspapi = 1, apikey = "charge_drop_rate"},
    {t = "@i18n(app.modules.power.smartfuel_sag_gain)@",          mspapi = 1, apikey = "sag_gain"},
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

local function getLocalSource()
    local bat = rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery
    if not bat then return 0 end
    local v = tonumber(bat.smartfuel_source) or tonumber(bat.calc_local) or 0
    return v
end

local function isTuningActive()
    local src = tonumber(sourceField.value) or 0
    if useFirmwareSmartFuel then
        if src == 0 then
            -- OFF (LOCAL): params apply only when local source is voltage (1)
            return getLocalSource() == 1
        end
        -- VOLTAGE (1): params apply; CURRENT (2): params do not apply
        return src == 1
    end
    -- Legacy (<12.9): source 0=current (no params), 1=voltage (params apply)
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

    for i = 2, #apidata.formdata.fields do
        local fieldHandle = rfsuite.app.formFields[i]
        if not fieldHandle or not fieldHandle.enable then break end
        fieldHandle:enable(tuningActive)
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
