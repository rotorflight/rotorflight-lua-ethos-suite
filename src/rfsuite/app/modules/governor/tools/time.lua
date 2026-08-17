--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware", showProgress = true})

local apidata = {
    api = {[1] = 'GOVERNOR_CONFIG'},
    formdata = {
        labels = {},
        fields = {
        --{t = "Startup time", mspapi = 1, apikey = "gov_startup_time"}, 
        {t = "Spoolup time", mspapi = 1, apikey = "gov_spoolup_time"}, 
        {t = "Spooldown time", mspapi = 1, apikey = "gov_spooldown_time"}, 
        {t = "Tracking time", mspapi = 1, apikey = "gov_tracking_time"}, 
        {t = "Recovery time", mspapi = 1, apikey = "gov_recovery_time"}}
    }
}

local function postLoad(self) rfsuite.app.triggers.closeProgressLoader = true end

local function event(widget, category, value, x, y)
    return navHandlers.event(widget, category, value)
end

local function onNavMenu()
    return navHandlers.onNavMenu()
end

local function wakeup()
    -- we are compromised if we don't have governor mode known
    if rfsuite.session.governorMode == nil then
        pageRuntime.openMenuContext({defaultSection = "hardware"})
        return
    end
end

return {apidata = apidata, reboot = true, eepromWrite = true, postLoad = postLoad, onNavMenu = onNavMenu, event = event, wakeup = wakeup}
