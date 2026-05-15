--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local onNavMenu

local apidata = {
    api = {[1] = "BATTERY_INI"},
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.power.model_type)@",    mspapi = 1, apikey = "smartfuel_model_type", type = 1},
            {t = "@i18n(app.modules.power.calcfuel_local)@", mspapi = 1, apikey = "smartfuel_source",    type = 1},
            {t = "@i18n(app.modules.power.smartfuel_end_at_zero)@", mspapi = 1, apikey = "smartfuel_end_at_zero", type = 1},
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
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

local function postSave(self)
    resetSmartfuel()
end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

onNavMenu = function(self)
    pageRuntime.openMenuContext({defaultSection = "hardware"})
    return true
end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, postLoad = postLoad, postSave = postSave, event = event, onNavMenu = onNavMenu}
