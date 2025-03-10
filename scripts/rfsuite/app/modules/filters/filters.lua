local mspapi = {
    api = {
        [1] = 'FILTER_CONFIG',
    },
    formdata = {
        labels = {
            {t = rfsuite.i18n.get("app.modules.filters.lowpass_1"),     label = 1, inline_size = 40.15},
            {t = "",                                                    label = 2, inline_size = 40.15},
            {t = rfsuite.i18n.get("app.modules.filters.lowpass_1_dyn"), label = 3, inline_size = 40.15},
            {t = "          ",                                          label = 4, inline_size = 40.15},
            {t = rfsuite.i18n.get("app.modules.filters.lowpass_2"),     label = 5, inline_size = 40.15},
            {t = "",                                                    label = 6, inline_size = 40.15},
            {t = rfsuite.i18n.get("app.modules.filters.notch_1"),       label = 7, inline_size = 13.6},
            {t = rfsuite.i18n.get("app.modules.filters.notch_2"),       label = 8, inline_size = 13.6}
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.filters.filter_type"), label = 1, inline = 1, mspapi = 1, apikey = "gyro_lpf1_type", type = 1},
            {t = rfsuite.i18n.get("app.modules.filters.cutoff"),      label = 2, inline = 1, mspapi = 1, apikey = "gyro_lpf1_static_hz"},
            {t = rfsuite.i18n.get("app.modules.filters.min_cutoff"),  label = 3, inline = 1, mspapi = 1, apikey = "gyro_lpf1_dyn_min_hz"},
            {t = rfsuite.i18n.get("app.modules.filters.max_cutoff"),  label = 4, inline = 1, mspapi = 1, apikey = "gyro_lpf1_dyn_max_hz"},
            {t = rfsuite.i18n.get("app.modules.filters.filter_type"), label = 5, inline = 1, mspapi = 1, apikey = "gyro_lpf2_type", type = 1},
            {t = rfsuite.i18n.get("app.modules.filters.cutoff"),      label = 6, inline = 1, mspapi = 1, apikey = "gyro_lpf2_static_hz"},
            {t = rfsuite.i18n.get("app.modules.filters.center"),      label = 7, inline = 2, mspapi = 1, apikey = "gyro_soft_notch_hz_1"},
            {t = rfsuite.i18n.get("app.modules.filters.cutoff"),      label = 7, inline = 1, mspapi = 1, apikey = "gyro_soft_notch_cutoff_1"},
            {t = rfsuite.i18n.get("app.modules.filters.center"),      label = 8, inline = 2, mspapi = 1, apikey = "gyro_soft_notch_hz_2"},
            {t = rfsuite.i18n.get("app.modules.filters.cutoff"),      label = 8, inline = 1, mspapi = 1, apikey = "gyro_soft_notch_cutoff_2"}
        }
    }                 
}


return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = true,
    API = {},
}
