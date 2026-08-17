--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local apidata = {
    api = {
        {id = 1, name = "FILTER_CONFIG", enableDeltaCache = false, rebuildOnWrite = true},
    },
    formdata = {
        labels = {
            { t = "Lowpass 1", label = 1, inline_size = 40.15 },
            { t = "", label = 2, inline_size = 40.15 },
            { t = "Lowpass 1 dyn.", label = 3, inline_size = 40.15 },
            { t = "          ", label = 4, inline_size = 40.15 },
            { t = "Lowpass 2", label = 5, inline_size = 40.15 },
            { t = "", label = 6, inline_size = 40.15 },
            { t = "Notch 1", label = 7, inline_size = 13.6 },
            { t = "Notch 2", label = 8, inline_size = 13.6 },
            { t = "Dynamic Filters", label = 9, inline_size = 13.6 },
            { t = "", label = 10, inline_size = 13.6 },
            { t = "RPM filter", label = 11, inline_size = 40.15 },
            { t = "", label = 12, inline_size = 40.15 }
        },
        fields = {
            { t = "Filter type", label = 1, inline = 1, mspapi = 1, apikey = "gyro_lpf1_type", type = 1 },
            { t = "Cutoff", label = 2, inline = 1, mspapi = 1, apikey = "gyro_lpf1_static_hz" },
            { t = "Min cutoff", label = 3, inline = 1, mspapi = 1, apikey = "gyro_lpf1_dyn_min_hz" },
            { t = "Max cutoff", label = 4, inline = 1, mspapi = 1, apikey = "gyro_lpf1_dyn_max_hz" },
            { t = "Filter type", label = 5, inline = 1, mspapi = 1, apikey = "gyro_lpf2_type", type = 1 },
            { t = "Cutoff", label = 6, inline = 1, mspapi = 1, apikey = "gyro_lpf2_static_hz" },
            { t = "Center", label = 7, inline = 2, mspapi = 1, apikey = "gyro_soft_notch_hz_1" },
            { t = "Cutoff", label = 7, inline = 1, mspapi = 1, apikey = "gyro_soft_notch_cutoff_1" },
            { t = "Center", label = 8, inline = 2, mspapi = 1, apikey = "gyro_soft_notch_hz_2" },
            { t = "Cutoff", label = 8, inline = 1, mspapi = 1, apikey = "gyro_soft_notch_cutoff_2" },
            { t = "Notch Count", label = 9, inline = 2, mspapi = 1, apikey = "dyn_notch_count" },
            { t = "Notch Q", label = 9, inline = 1, mspapi = 1, apikey = "dyn_notch_q" },
            { t = "Min", label = 10, inline = 2, mspapi = 1, apikey = "dyn_notch_min_hz" },
            { t = "Max", label = 10, inline = 1, mspapi = 1, apikey = "dyn_notch_max_hz" },
            { t = "Type", label = 11, inline = 1, mspapi = 1, apikey = "rpm_preset", type = 1, apiversiongte = {12, 0, 8} },
            { t = "Min. Frequency", label = 12, inline = 1, mspapi = 1, apikey = "rpm_min_hz", apiversiongte = {12, 0, 8} }
        }
    }
}

return {apidata = apidata, eepromWrite = true, reboot = true, API = {}}
