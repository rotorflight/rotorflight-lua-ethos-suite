--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local useFirmwareSmartFuel = rfsuite.utils.apiVersionCompare(">=", {12, 0, 10})

local apidata

if useFirmwareSmartFuel then
    apidata = {
        api = {
            [1] = "BATTERY_INI",
            [2] = "SMARTFUEL_CONFIG"
        },
        formdata = {
            labels = {},
            fields = {
                {t = "@i18n(app.modules.power.model_type)@",                    mspapi = 1, apikey = "smartfuel_model_type", type = 1},
                {t = "@i18n(app.modules.power.calcfuel_local)@",                mspapi = 2, apikey = "smartfuel_source", type = 1},
                {t = "@i18n(app.modules.power.smartfuel_stabilize_delay)@",     mspapi = 2, apikey = "stabilize_delay"},
                {t = "@i18n(app.modules.power.smartfuel_stable_window)@",       mspapi = 2, apikey = "stable_window"},
                {t = "@i18n(app.modules.power.smartfuel_sag_compensation)@",    mspapi = 2, apikey = "sag_multiplier_percent"},
                {t = "@i18n(app.modules.power.smartfuel_voltage_fall_limit)@",  mspapi = 2, apikey = "voltage_fall_limit"},
                {t = "@i18n(app.modules.power.smartfuel_fuel_drop_rate)@",      mspapi = 2, apikey = "fuel_drop_rate"},
                {t = "@i18n(app.modules.power.smartfuel_fuel_rise_rate)@",      mspapi = 2, apikey = "fuel_rise_rate"},
            }
        }
    }
else
    apidata = {
        api = {
            [1] = "BATTERY_INI"
        },
        formdata = {
            labels = {},
            fields = {
                {t = "@i18n(app.modules.power.model_type)@",                    mspapi = 1, apikey = "smartfuel_model_type", type = 1},
                {t = "@i18n(app.modules.power.calcfuel_local)@",                mspapi = 1, apikey = "smartfuel_source", type = 1},
                {t = "@i18n(app.modules.power.smartfuel_stabilize_delay)@",     mspapi = 1, apikey = "stabilize_delay"},
                {t = "@i18n(app.modules.power.smartfuel_stable_window)@",       mspapi = 1, apikey = "stable_window"},
                {t = "@i18n(app.modules.power.smartfuel_sag_compensation)@",    mspapi = 1, apikey = "sag_multiplier_percent"},
                {t = "@i18n(app.modules.power.smartfuel_voltage_fall_limit)@",  mspapi = 1, apikey = "voltage_fall_limit"},
                {t = "@i18n(app.modules.power.smartfuel_fuel_drop_rate)@",      mspapi = 1, apikey = "fuel_drop_rate"},
                {t = "@i18n(app.modules.power.smartfuel_fuel_rise_rate)@",      mspapi = 1, apikey = "fuel_rise_rate"},
            }
        }
    }
end

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
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

    for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "voltage_fall_limit" or
           f.apikey == "fuel_drop_rate" or
           f.apikey == "fuel_rise_rate" or
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

return {wakeup = wakeup, apidata = apidata, eepromWrite = true, reboot = false, API = {}, postLoad = postLoad, event = event, onNavMenu = onNavMenu}
