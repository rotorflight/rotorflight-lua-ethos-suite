
local mspapi = {
    api = {
        [1] = 'MIXER_CONFIG',
    },
    formdata = {
        labels = {
            {t = rfsuite.i18n.get("app.modules.mixer.collective_tilt_correction"),  inline_size = 35,    label = 1},
            {t = "                           ", inline_size = 35,    label = 2}
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.mixer.geo_correction"),                  api = "MIXER_CONFIG:swash_geo_correction"},
            {t = rfsuite.i18n.get("app.modules.mixer.swash_pitch_limit"),               api = "MIXER_CONFIG:swash_pitch_limit"},
            {t = rfsuite.i18n.get("app.modules.mixer.collective_tilt_correction_pos"),  api = "MIXER_CONFIG:collective_tilt_correction_pos", inline = 1, label = 1, apiversiongt = 12.08},
            {t = rfsuite.i18n.get("app.modules.mixer.collective_tilt_correction_neg"),  api = "MIXER_CONFIG:collective_tilt_correction_neg", inline = 1, label = 2, apiversiongt = 12.08},
            {t = rfsuite.i18n.get("app.modules.mixer.swash_phase"),                     api = "MIXER_CONFIG:swash_phase"},
            {t = rfsuite.i18n.get("app.modules.mixer.swash_tta_precomp"),               api = "MIXER_CONFIG:swash_tta_precomp"},
            {t = rfsuite.i18n.get("app.modules.mixer.tail_motor_idle"),                 api = "MIXER_CONFIG:tail_motor_idle", enablefunction = function() return (rfsuite.session.tailMode >= 1) end},
        }
    }                 
}

return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    API = {},
}
