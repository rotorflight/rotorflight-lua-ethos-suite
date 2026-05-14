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
local TUNING_FIELD_START = useFirmwareSmartFuel and 2 or 1
local INI_SECTION = "battery"

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

if useFirmwareSmartFuel then
    sourceField.postEdit = function(self, value)
        lastTuningActive = nil
    end
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
    -- Legacy (<12.9): read source from preferences (not form field)
    return getLocalSource() == 1
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

local function resetSmartfuel()
    local sensors = rfsuite.tasks and rfsuite.tasks.sensors
    if sensors and type(sensors.resetSmart) == "function" then
        sensors.resetSmart()
    end

    local eventTelemetry = rfsuite.tasks and rfsuite.tasks.events and rfsuite.tasks.events.telemetry
    if eventTelemetry and type(eventTelemetry.resetSmartfuelAlertState) == "function" then
        eventTelemetry.resetSmartfuelAlertState()
    end
end

local function getTuningValue(key)
    local fields = apidata.formdata.fields
    for i = TUNING_FIELD_START, #fields do
        local field = fields[i]
        if field and field.apikey == key then
            return tonumber(field.value)
        end
    end
    return nil
end

local function writeLocalSmartfuelSettings()
    if not useFirmwareSmartFuel then return end

    local session = rfsuite.session
    local mcuId = session and session.mcu_id
    if not mcuId then return end

    local iniFile = "SCRIPTS:/" .. rfsuite.config.preferences .. "/models/" .. mcuId .. ".ini"
    local ini = rfsuite.ini
    local tbl = ini.load_ini_file(iniFile) or {}

    local voltageDropRate = getTuningValue("voltage_drop_rate")
    local chargeDropRate = getTuningValue("charge_drop_rate")
    local sagGain = getTuningValue("sag_gain")

    if voltageDropRate ~= nil then
        voltageDropRate = math.floor(voltageDropRate + 0.5)
        ini.setvalue(tbl, INI_SECTION, "voltage_drop_rate", voltageDropRate)
    end
    if chargeDropRate ~= nil then
        chargeDropRate = math.floor(chargeDropRate * 100 + 0.5)
        ini.setvalue(tbl, INI_SECTION, "charge_drop_rate", chargeDropRate)
    end
    if sagGain ~= nil then
        sagGain = math.floor(sagGain + 0.5)
        ini.setvalue(tbl, INI_SECTION, "sag_gain", sagGain)
    end

    local ok, err = ini.save_ini_file(iniFile, tbl)
    if not ok then
        rfsuite.utils.log("Failed to save local SmartFuel settings: " .. tostring(err or iniFile), "info")
        return
    end

    local batteryPrefs = session.modelPreferences and session.modelPreferences[INI_SECTION]
    if batteryPrefs then
        if voltageDropRate ~= nil then batteryPrefs.voltage_drop_rate = voltageDropRate end
        if chargeDropRate ~= nil then batteryPrefs.charge_drop_rate = chargeDropRate end
        if sagGain ~= nil then batteryPrefs.sag_gain = sagGain end
    end
end

local function postSave(self)
    if useFirmwareSmartFuel then
        rfsuite.session = rfsuite.session or {}
        rfsuite.session.batteryConfig = rfsuite.session.batteryConfig or {}
        rfsuite.session.batteryConfig.smartfuelRemoteSource = tonumber(sourceField.value) or 0
        writeLocalSmartfuelSettings()
    end
    resetSmartfuel()
end

local function wakeup(self)
    if not enableWakeup then return end

    local tuningActive = isTuningActive()

    if tuningActive == lastTuningActive then return end
    lastTuningActive = tuningActive

    for i = TUNING_FIELD_START, #apidata.formdata.fields do
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
