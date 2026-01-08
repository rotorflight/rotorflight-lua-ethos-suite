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
            {t = "@i18n(app.modules.mixer.geo_correction)@",                    api = "MIXER_CONFIG:swash_geo_correction"},
            {t = "@i18n(app.modules.mixer.swash_pitch_limit)@",                 api = "MIXER_CONFIG:swash_pitch_limit"},
            {t = "@i18n(app.modules.mixer.collective_tilt_correction_pos)@",    api = "MIXER_CONFIG:collective_tilt_correction_pos", apiversiongte = 12.08},
            {t = "@i18n(app.modules.mixer.collective_tilt_correction_neg)@",    api = "MIXER_CONFIG:collective_tilt_correction_neg", apiversiongte = 12.08},
            {t = "@i18n(app.modules.mixer.swash_phase)@",                       api = "MIXER_CONFIG:swash_phase"},
        }
    }
}

local function onNavMenu(self)

    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")

end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu}
