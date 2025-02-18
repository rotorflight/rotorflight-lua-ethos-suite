local mspapi = {
    api = {
        [1] = 'FILTER_CONFIG',
    },
    formdata = {
        labels = {
            {t = "Gyro lowpass 1", t2 = "Lowpass 1",              label = 1, inline_size = 40.15},
            {t = "",                                              label = 2, inline_size = 40.15},
            {t = "Gyro lowpass 1 dynamic", t2 = "Lowpass 1 dyn.", label = 3, inline_size = 40.15,},
            {t = "          ",                                    label = 4, inline_size = 40.15},
            {t = "Gyro lowpass 2", t2 = "Lowpass 2",              label = 5, inline_size = 40.15},
            {t = "",                                              label = 6, inline_size = 40.15},
            {t = "Gyro notch 1", t2 = "Notch 1",                  label = 7 , inline_size = 13.6},
            {t = "Gyro notch 2", t2 = "Notch 2",                  label = 8, inline_size = 13.6}
        },
        fields = {
            {t = "Filter type", label = 1, inline = 1, mspapi = 1, apikey = "gyro_lpf1_type", type = 1},
            {t = "Cutoff",      label = 2, inline = 1, mspapi = 1, apikey = "gyro_lpf1_static_hz"},
            {t = "Min cutoff",  label = 3, inline = 1, mspapi = 1, apikey = "gyro_lpf1_dyn_min_hz"},
            {t = "Max cutoff",  label = 4, inline = 1, mspapi = 1, apikey = "gyro_lpf1_dyn_max_hz"},
            {t = "Filter type", label = 5, inline = 1, mspapi = 1, apikey = "gyro_lpf2_type", type = 1},
            {t = "Cutoff",      label = 6, inline = 1, mspapi = 1, apikey = "gyro_lpf2_static_hz"},
            {t = "Center",      label = 7, inline = 2, mspapi = 1, apikey = "gyro_soft_notch_hz_1"},
            {t = "Cutoff",      label = 7, inline = 1, mspapi = 1, apikey = "gyro_soft_notch_cutoff_1"},
            {t = "Center",      label = 8, inline = 2, mspapi = 1, apikey = "gyro_soft_notch_hz_2"},
            {t = "Cutoff",      label = 8, inline = 1, mspapi = 1, apikey = "gyro_soft_notch_cutoff_2"}
        }
    }                 
}


return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = true,
    title = "Filters",
    API = {},
}
