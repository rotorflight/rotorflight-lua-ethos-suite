--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local apidata = {
    api = {
        [1] = 'BATTERY_CONFIG',
    },
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.power.max_cell_voltage)@",           mspapi = 1, apikey = "vbatmaxcellvoltage"},
            {t = "@i18n(app.modules.power.full_cell_voltage)@",          mspapi = 1, apikey = "vbatfullcellvoltage"},
            {t = "@i18n(app.modules.power.warn_cell_voltage)@",          mspapi = 1, apikey = "vbatwarningcellvoltage"},
            {t = "@i18n(app.modules.power.min_cell_voltage)@",           mspapi = 1, apikey = "vbatmincellvoltage"},
            {t = "@i18n(app.modules.power.battery_capacity)@",           mspapi = 1, apikey = "batteryCapacity"},
            {t = "@i18n(app.modules.power.cell_count)@",                 mspapi = 1, apikey = "batteryCellCount"},
            {t = "@i18n(app.modules.power.consumption_warning_percentage)@", min = 15, max = 60, mspapi = 1, apikey = "consumptionWarningPercentage"},
        }
    }
}

local function postLoad(self)
    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "consumptionWarningPercentage" then
            local v = tonumber(f.value)
            if v then
                if v < 15 then
                    f.value = 35
                elseif v > 60 then
                    f.value = 35
                end
            end
        end
    end
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function wakeup(self)
    if enableWakeup == false then return end
end


local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

onNavMenu = function(self)
    pageRuntime.openMenuContext({defaultSection = "hardware"})
    return true
end


return {event = event, wakeup = wakeup, apidata = apidata, eepromWrite = true, reboot = false, API = {}, postLoad = postLoad, onNavMenu = onNavMenu}
