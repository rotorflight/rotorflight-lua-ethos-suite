--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apidata = {
    api = {
        [1] = 'MIXER_CONFIG',
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.mixer.swash_tta_precomp)@",                 api = "MIXER_CONFIG:swash_tta_precomp"},

        }
    }
}

local function onNavMenu(self)

    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")

end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu}
