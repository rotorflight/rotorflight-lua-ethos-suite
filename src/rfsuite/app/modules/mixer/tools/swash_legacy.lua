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
            {t = "Geo Correction",                    api = "MIXER_CONFIG:swash_geo_correction"},
            {t = "Total Pitch Limit",                 api = "MIXER_CONFIG:swash_pitch_limit"},
            {t = "Collective Tilt Correction +",    api = "MIXER_CONFIG:collective_tilt_correction_pos", apiversiongte = {12, 0, 8}},
            {t = "Collective Tilt Correction -",    api = "MIXER_CONFIG:collective_tilt_correction_neg", apiversiongte = {12, 0, 8}},
            {t = "Phase Angle",                       api = "MIXER_CONFIG:swash_phase"},
        }
    }
}

local function onNavMenu(self)

    pageRuntime.openMenuContext()

end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu}
