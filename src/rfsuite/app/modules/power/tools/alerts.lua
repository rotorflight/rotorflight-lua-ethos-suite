--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local disableMultiplier
local becAlert
local rxBattAlert

local apidata = {
    api = {
        [1] = 'BATTERY_INI'
    },
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.power.calcfuel_local)@",             mspapi = 1, apikey = "calc_local", type = 1},
            {t = "@i18n(app.modules.power.timer)@",                      mspapi = 1, apikey = "flighttime"},
            {t = "@i18n(app.modules.power.voltage_multiplier)@",         mspapi = 1, apikey = "sag_multiplier"},
            {t = "@i18n(app.modules.power.alert_type)@",                 mspapi = 1, apikey = "alert_type", type = 1},
            {t = "@i18n(app.modules.power.bec_voltage_alert)@",          mspapi = 1, apikey = "becalertvalue"},
            {t = "@i18n(app.modules.power.rx_voltage_alert)@",           mspapi = 1, apikey = "rxalertvalue"}
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function wakeup(self)
    if enableWakeup == false then return end

    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "calc_local" then
            local v = tonumber(f.value)
            if v == 1 then
                disableMultiplier = true
            else
                disableMultiplier = false
            end
        end
    end

    if disableMultiplier == true then
        for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do if f.apikey == "sag_multiplier" then rfsuite.app.formFields[i]:enable(true) end end
    else
        for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do if f.apikey == "sag_multiplier" then rfsuite.app.formFields[i]:enable(false) end end
    end

    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "alert_type" then
            local b = tonumber(f.value)
            if b == 1 then
                becAlert = true
                rxBattAlert = false
            elseif b == 2 then
                becAlert = false
                rxBattAlert = true
            else
                becAlert = false
                rxBattAlert = false
            end
        end
    end

    for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "becalertvalue" then
            rfsuite.app.formFields[i]:enable(becAlert)
        elseif f.apikey == "rxalertvalue" then
            rfsuite.app.formFields[i]:enable(rxBattAlert)
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
