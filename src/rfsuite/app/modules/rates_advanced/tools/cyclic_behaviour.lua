--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local navHandlers = pageRuntime.createMenuHandlers({defaultSection = "hardware"})

local apidata = {
    api = {
        {id = 1, name = "RC_TUNING"},
    },
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.rates_advanced.cyclic_polarity)@", mspapi = 1, apikey = "cyclic_polarity", type = 1, apiversiongte = {12, 0, 9}},
            {t = "@i18n(app.modules.rates_advanced.cyclic_ring)@", mspapi = 1, apikey = "cyclic_ring", apiversiongte = {12, 0, 9}}
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
end

return {apidata = apidata, title = "@i18n(app.modules.rates_advanced.cyclic_behaviour)@", onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, reboot = false, eepromWrite = true, refreshOnRateChange = true, postLoad = postLoad, API = {}}
