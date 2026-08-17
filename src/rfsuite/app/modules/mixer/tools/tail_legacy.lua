--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local apidata = {
    api = {
        [1] = 'MIXER_CONFIG',
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Tail Motor idle  %",    mspapi = 1, apikey = "tail_motor_idle", enablefunction = function() return (rfsuite.session.tailMode >= 1) end},
            {t = "Yaw. trim %",          mspapi = 1, apikey = "tail_center_trim", enablefunction = function() return (rfsuite.session.tailMode == 0) end},
            {t = "TTA Precomp",                 api = "MIXER_CONFIG:swash_tta_precomp"},

        }
    }
}

local function onNavMenu(self)

    pageRuntime.openMenuContext()

end

local function wakeup()

    -- we are compromised without this - go back to main
    if rfsuite.session.tailMode == nil then
        pageRuntime.openMenuContext()
    end

end

return {wakeup = wakeup, apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu}
