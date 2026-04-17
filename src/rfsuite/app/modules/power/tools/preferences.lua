--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local lastVoltageMode = nil
local useFirmwareSmartFuel = rfsuite.utils.apiVersionCompare(">=", {12, 0, 10})

local function buildFields()
    local fields = {}

    if useFirmwareSmartFuel then
        fields[#fields + 1] = {t = "@i18n(sensors.smartfuel)@", mspapi = 2, apikey = "smartfuel_remote_source", type = 1}
    end

    fields[#fields + 1] = {t = "@i18n(app.modules.power.model_type)@",                    mspapi = 1, apikey = "smartfuel_model_type", type = 1}
    fields[#fields + 1] = {t = "@i18n(app.modules.power.calcfuel_local)@",                mspapi = 1, apikey = "smartfuel_source", type = 1}
    fields[#fields + 1] = {t = "@i18n(app.modules.power.smartfuel_stabilize_delay)@",     mspapi = 1, apikey = "stabilize_delay"}
    fields[#fields + 1] = {t = "@i18n(app.modules.power.smartfuel_stable_window)@",       mspapi = 1, apikey = "stable_window"}
    fields[#fields + 1] = {t = "@i18n(app.modules.power.smartfuel_sag_compensation)@",    mspapi = 1, apikey = "sag_multiplier_percent"}
    fields[#fields + 1] = {t = "@i18n(app.modules.power.smartfuel_voltage_fall_limit)@",  mspapi = 1, apikey = "voltage_fall_limit"}
    fields[#fields + 1] = {t = "@i18n(app.modules.power.smartfuel_fuel_drop_rate)@",      mspapi = 1, apikey = "fuel_drop_rate"}

    return fields
end

local function buildApiData()
    if useFirmwareSmartFuel then
        return {
            api = {
                [1] = "BATTERY_INI",
                [2] = "BATTERY_CONFIG"
            },
            formdata = {
                labels = {},
                fields = buildFields()
            }
        }
    end

    return {
        api = {
            [1] = "BATTERY_INI"
        },
        formdata = {
            labels = {},
            fields = buildFields()
        }
    }
end

local apidata = buildApiData()

local function postLoad(self)
    lastVoltageMode = nil
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function postSave(self)
    if not useFirmwareSmartFuel then
        return
    end

    local remoteSmartfuelSource = 0
    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "smartfuel_remote_source" then
            remoteSmartfuelSource = tonumber(f.value) or 0
            break
        end
    end

    rfsuite.session = rfsuite.session or {}
    rfsuite.session.batteryConfig = rfsuite.session.batteryConfig or {}
    rfsuite.session.batteryConfig.smartfuelRemoteSource = remoteSmartfuelSource

    if rfsuite.tasks and rfsuite.tasks.sensors and type(rfsuite.tasks.sensors.resetSmart) == "function" then
        rfsuite.tasks.sensors.resetSmart()
    end
end

local function wakeup(self)
    if enableWakeup == false then return end
    local voltageMode = false
    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "smartfuel_source" then
            voltageMode = tonumber(f.value) == 1
            break
        end
    end

    if voltageMode == lastVoltageMode then
        return
    end
    lastVoltageMode = voltageMode

    for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "voltage_fall_limit" or
           f.apikey == "fuel_drop_rate" or
           f.apikey == "sag_multiplier_percent" then
            local fieldHandle = rfsuite.app.formFields[i]
            if fieldHandle and fieldHandle.enable then
                fieldHandle:enable(voltageMode)
            end
        end
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
