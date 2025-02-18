
local mspapi = {
    api = {
        [1] = 'MIXER_CONFIG',
    },
    formdata = {
        labels = {
            {t = "Collective Tilt Correction",  inline_size = 35,    label = 1},
            {t = "                           ", inline_size = 35,    label = 2}
        },
        fields = {
            {t = "Geo correction",        mspapi = 1, apikey = "swash_geo_correction"},
            {t = "Total pitch limit",     mspapi = 1, apikey = "swash_pitch_limit"},
            {t = "Positive",              mspapi = 1, apikey = "collective_tilt_correction_pos", inline = 1, label = 1, apiversiongt = 12.08},
            {t = "Negative",              mspapi = 1, apikey = "collective_tilt_correction_neg", inline = 1, label = 2, apiversiongt = 12.08},
            {t = "Phase angle",           mspapi = 1, apikey = "swash_phase"},
            {t = "TTA precomp",           mspapi = 1, apikey = "swash_tta_precomp"},
            {t = "Tail Idle Thr%",        mspapi = 1, apikey = "tail_motor_idle", enablefunction = function() return (rfsuite.session.tailMode >= 1) end},
        }
    }                 
}

return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Mixer",
    API = {},
}
