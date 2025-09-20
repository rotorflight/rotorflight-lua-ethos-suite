
local apidata = {
    api = {
        [1] = 'MIXER_CONFIG',
    },
    formdata = {
        labels = {
            {t = "@i18n(app.modules.mixer.collective_tilt_correction)@",  inline_size = 35,    label = 1},
            {t = "                           ", inline_size = 35,    label = 2}
        },
        fields = {
            {t = "@i18n(app.modules.mixer.geo_correction)@",                  api = "MIXER_CONFIG:swash_geo_correction"},
            {t = "@i18n(app.modules.mixer.swash_pitch_limit)@",               api = "MIXER_CONFIG:swash_pitch_limit"},
            {t = "@i18n(app.modules.mixer.collective_tilt_correction_pos)@",  api = "MIXER_CONFIG:collective_tilt_correction_pos", inline = 1, label = 1, apiversiongte = 12.08},
            {t = "@i18n(app.modules.mixer.collective_tilt_correction_neg)@",  api = "MIXER_CONFIG:collective_tilt_correction_neg", inline = 1, label = 2, apiversiongte = 12.08},
            {t = "@i18n(app.modules.mixer.swash_phase)@",                     api = "MIXER_CONFIG:swash_phase"},
            {t = "@i18n(app.modules.mixer.swash_tta_precomp)@",               api = "MIXER_CONFIG:swash_tta_precomp"},
            {t = "@i18n(app.modules.mixer.tail_motor_idle)@",                 api = "MIXER_CONFIG:tail_motor_idle", enablefunction = function() return (rfsuite.session.tailMode >= 1) end},
        }
    }                 
}

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    API = {},
}
