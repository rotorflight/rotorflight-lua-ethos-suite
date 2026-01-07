--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apidata = {
    api = {
        [1] = 'MIXER_CONFIG',
        [2] = 'MIXER_INPUT_INDEXED_YAW',
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.mixer.tail_rotor_mode)@",         mspapi=1, apikey="tail_rotor_mode", type = 1},
             {t = "@i18n(app.modules.mixer.yaw_direction)@",          mspapi = 2, apikey="rate_stabilized_yaw", type = 1, tableEthos = { [1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 }, [2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 },}},  
            {t = "@i18n(app.modules.trim.tail_motor_idle)@",          mspapi = 1, apikey = "tail_motor_idle", enablefunction = function() return (rfsuite.session.tailMode >= 1) end},
           -- {t = "@i18n(app.modules.mixer.swash_tta_precomp)@",       api = "MIXER_CONFIG:swash_tta_precomp", enablefunction = function() return (rfsuite.session.tailMode >= 1) end},

        }
    }
}

local function onNavMenu(self)

    rfsuite.app.ui.openPage(pidx, title, "mixer/mixer.lua")

end

return {apidata = apidata, eepromWrite = true, reboot = false, API = {}, onNavMenu=onNavMenu}
