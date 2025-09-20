

local apidata = {
    api = {
        [1] = 'FILTER_CONFIG',
    },
    formdata = {
        labels = {
            {t = "@i18n(app.modules.filters.lowpass_1)@",     label = 1, inline_size = 40.15},
            {t = "",                                                    label = 2, inline_size = 40.15},
            {t = "@i18n(app.modules.filters.lowpass_1_dyn)@", label = 3, inline_size = 40.15},
            {t = "          ",                                          label = 4, inline_size = 40.15},
            {t = "@i18n(app.modules.filters.lowpass_2)@",     label = 5, inline_size = 40.15},
            {t = "",                                                    label = 6, inline_size = 40.15},
            {t = "@i18n(app.modules.filters.notch_1)@",       label = 7, inline_size = 13.6},
            {t = "@i18n(app.modules.filters.notch_2)@",       label = 8, inline_size = 13.6},
            {t = "@i18n(app.modules.filters.dyn_notch)@",     label = 9, inline_size = 13.6},
            {t = "",                                                    label = 10, inline_size = 13.6},
            {t = "@i18n(app.modules.filters.rpm_filter)@",    label = 11, inline_size = 40.15},
            {t = "",                                                    label = 12, inline_size = 40.15},
        },
        fields = {
            {t = "@i18n(app.modules.filters.filter_type)@", label = 1, inline = 1, mspapi = 1, apikey = "gyro_lpf1_type", type = 1},
            {t = "@i18n(app.modules.filters.cutoff)@",      label = 2, inline = 1, mspapi = 1, apikey = "gyro_lpf1_static_hz"},
            {t = "@i18n(app.modules.filters.min_cutoff)@",  label = 3, inline = 1, mspapi = 1, apikey = "gyro_lpf1_dyn_min_hz"},
            {t = "@i18n(app.modules.filters.max_cutoff)@",  label = 4, inline = 1, mspapi = 1, apikey = "gyro_lpf1_dyn_max_hz"},
            {t = "@i18n(app.modules.filters.filter_type)@", label = 5, inline = 1, mspapi = 1, apikey = "gyro_lpf2_type", type = 1},
            {t = "@i18n(app.modules.filters.cutoff)@",      label = 6, inline = 1, mspapi = 1, apikey = "gyro_lpf2_static_hz"},
            {t = "@i18n(app.modules.filters.center)@",      label = 7, inline = 2, mspapi = 1, apikey = "gyro_soft_notch_hz_1"},
            {t = "@i18n(app.modules.filters.cutoff)@",      label = 7, inline = 1, mspapi = 1, apikey = "gyro_soft_notch_cutoff_1"},
            {t = "@i18n(app.modules.filters.center)@",      label = 8, inline = 2, mspapi = 1, apikey = "gyro_soft_notch_hz_2"},
            {t = "@i18n(app.modules.filters.cutoff)@",      label = 8, inline = 1, mspapi = 1, apikey = "gyro_soft_notch_cutoff_2"},
            {t = "@i18n(app.modules.filters.notch_c)@",     label = 9, inline = 2, mspapi = 1, apikey = "dyn_notch_count"},
            {t = "@i18n(app.modules.filters.notch_q)@",     label = 9, inline = 1, mspapi = 1, apikey = "dyn_notch_q"},
            {t = "@i18n(app.modules.filters.notch_min_hz)@",label = 10, inline = 2, mspapi = 1, apikey = "dyn_notch_min_hz"},
            {t = "@i18n(app.modules.filters.notch_max_hz)@",label = 10, inline = 1, mspapi = 1, apikey = "dyn_notch_max_hz"},
            {t = "@i18n(app.modules.filters.rpm_preset)@",  label = 11, inline = 1, mspapi = 1, apikey = "rpm_preset", type = 1, apiversiongte = 12.08},
            {t = "@i18n(app.modules.filters.rpm_min_hz)@",  label = 12, inline = 1, mspapi = 1, apikey = "rpm_min_hz", apiversiongte = 12.08},
        }
    }                 
}


return {
    apidata = apidata,
    eepromWrite = true,
    reboot = true,
    API = {},
}
