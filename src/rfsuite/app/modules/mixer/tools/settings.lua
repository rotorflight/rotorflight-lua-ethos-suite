--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apidata = {
    api = {
        [1] = 'MIXER_CONFIG',
        [2] = 'MIXER_INPUT_INDEXED_ROLL',
        [3] = 'MIXER_INPUT_INDEXED_PITCH',
        [4] = 'MIXER_INPUT_INDEXED_YAW',
        [5] = 'MIXER_INPUT_INDEXED_COLLECTIVE',
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.mixer.swash_type)@",                    api = "MIXER_CONFIG:swash_type", type = 1},
            {t = "@i18n(app.modules.mixer.main_rotor_dir)@",                api = "MIXER_CONFIG:main_rotor_dir", type = 1},
            {t = "@i18n(app.modules.mixer.tail_rotor_mode)@",               api = "MIXER_CONFIG:tail_rotor_mode", type = 1},
            {t = "@i18n(app.modules.mixer.aileron_direction)@",             api = "MIXER_INPUT_INDEXED_ROLL:rate", type = 1},
            {t = "@i18n(app.modules.mixer.elevator_direction)@",            api = "MIXER_INPUT_INDEXED_PITCH:rate", type = 1},
            {t = "@i18n(app.modules.mixer.collective_direction)@",          api = "MIXER_INPUT_INDEXED_COLLECTIVE:rate", type = 1},            
            {t = "@i18n(app.modules.mixer.yaw_direction)@",                 api = "MIXER_INPUT_INDEXED_YAW:rate", type = 1},
        }
    }
}

local function onNavMenu(self)

    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")

end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu}
