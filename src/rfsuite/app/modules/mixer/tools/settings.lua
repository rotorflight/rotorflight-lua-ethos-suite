--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apidata = {
    api = {
        [1] = 'MIXER_INPUT_INDEXED_ROLL',
        [2] = 'MIXER_INPUT_INDEXED_PITCH',
        [3] = 'MIXER_INPUT_INDEXED_YAW',
        [4] = 'MIXER_INPUT_INDEXED_COLLECTIVE',
       -- [5] = 'MIXER_CONFIG',
    },
    formdata = {
        labels = {
        },
        fields = {
         --   {t = "@i18n(app.modules.mixer.swash_type)@",                    api = "MIXER_CONFIG:swash_type", type = 1},
         --   {t = "@i18n(app.modules.mixer.main_rotor_dir)@",                api = "MIXER_CONFIG:main_rotor_dir", type = 1},
         --   {t = "@i18n(app.modules.mixer.tail_rotor_mode)@",               api = "MIXER_CONFIG:tail_rotor_mode", type = 1},
            {t = "@i18n(app.modules.mixer.aileron_direction)@",             mspapi = 1, apikey="rate", type = 1},
            {t = "@i18n(app.modules.mixer.elevator_direction)@",            mspapi = 2, apikey="rate", type = 1},
            {t = "@i18n(app.modules.mixer.collective_direction)@",          mspapi = 4, apikey="rate", type = 1},            
            {t = "@i18n(app.modules.mixer.yaw_direction)@",                 mspapi = 3, apikey="rate", type = 1},
        }
    }
}

local function onNavMenu(self)

    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")

end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu}
