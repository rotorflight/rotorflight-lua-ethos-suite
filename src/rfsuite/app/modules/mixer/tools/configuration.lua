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
            {t = "@i18n(app.modules.mixer.swash_type)@",                    mspapi=1, apikey="swash_type", type = 1},
            {t = "@i18n(app.modules.mixer.main_rotor_dir)@",                mspapi=1, apikey="main_rotor_dir", type = 1},
            {t = "@i18n(app.modules.mixer.tail_rotor_mode)@",               mspapi=1, apikey="tail_rotor_mode", type = 1},
        }
    }
}


local function onNavMenu(self)

    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")

end


return {wakeup = wakeup, apidata = apidata, eepromWrite = true, postLoad = postLoad, reboot = false, API = {}, onNavMenu=onNavMenu, onSaveMenu = onSaveMenu}
