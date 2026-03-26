--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local onNavMenu
local FIELDS = {
    voltageMeterSource = 1,
    currentMeterSource = 2
}

local apidata = {
    api = {
        [1] = 'BATTERY_CONFIG'
    },
    formdata = {
        labels = {},
        fields = {
              [FIELDS.voltageMeterSource] = {t = "@i18n(app.modules.power.voltage_meter_source)@",       mspapi = 1, apikey = "voltageMeterSource", type = 1},
              [FIELDS.currentMeterSource] = {t = "@i18n(app.modules.power.current_meter_source)@",       mspapi = 1, apikey = "currentMeterSource", type = 1}
        }
    }
}

local function postLoad(self)
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
