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
        [4] = 'MIXER_INPUT_INDEXED_COLLECTIVE',
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.mixer.swash_type)@",                    mspapi=1, apikey="swash_type", type = 1, },
            {t = "@i18n(app.modules.mixer.main_rotor_dir)@",                mspapi=1, apikey="main_rotor_dir", type = 1, tableEthos = { [1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 }, [2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 },}},            
            {t = "@i18n(app.modules.mixer.aileron_direction)@",             mspapi = 2, apikey="rate_stabilized_roll", type = 1, tableEthos = { [1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 }, [2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 },}},
            {t = "@i18n(app.modules.mixer.elevator_direction)@",            mspapi = 3, apikey="rate_stabilized_pitch", type = 1, tableEthos = { [1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 }, [2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 },}},
            {t = "@i18n(app.modules.mixer.collective_direction)@",          mspapi = 4, apikey="rate_stabilized_collective", type = 1, tableEthos = { [1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 }, [2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 },}},            
        }
    }
}

local function onNavMenu(self)

    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")

end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu}


