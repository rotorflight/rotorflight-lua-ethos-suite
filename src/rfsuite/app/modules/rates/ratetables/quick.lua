--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local apidata = {
    api = {
        {id = 1, name = "RC_TUNING", enableDeltaCache = false, rebuildOnWrite = true},
    },
    formdata = {
        name = "@i18n(app.modules.rates.quick)@",
        labels = {},
        rows = {
            "@i18n(app.modules.rates.roll)@",
            "@i18n(app.modules.rates.pitch)@",
            "@i18n(app.modules.rates.yaw)@",
            "@i18n(app.modules.rates.collective)@"
        },
        cols = {
            "@i18n(app.modules.rates.rc_rate)@",
            "@i18n(app.modules.rates.max_rate)@",
            "@i18n(app.modules.rates.expo)@"
        },
        fields = {
            -- RC Rate
            {row = 1, col = 1, min = 0,    max = 2550,   default = 120,    decimals = 2, scale = 100, mspapi = 1, apikey = "rcRates_1"},
            {row = 2, col = 1, min = 0,    max = 2550,   default = 120,    decimals = 2, scale = 100, mspapi = 1, apikey = "rcRates_2"},
            {row = 3, col = 1, min = 0,    max = 2550,   default = 200,    decimals = 2, scale = 100, mspapi = 1, apikey = "rcRates_3"},
            {row = 4, col = 1, min = 0,    max = 2550,   default = 250,    decimals = 2, scale = 100, mspapi = 1, apikey = "rcRates_4"},
            -- Max Rate
            {row = 1, col = 2, min = 0,    max = 1000,   default = 24,     mult = 10, step = 10, mspapi = 1, apikey = "rates_1"},
            {row = 2, col = 2, min = 0,    max = 1000,   default = 24,     mult = 10, step = 10, mspapi = 1, apikey = "rates_2"},
            {row = 3, col = 2, min = 0,    max = 1000,   default = 40,     mult = 10, step = 10, mspapi = 1, apikey = "rates_3"},
            {row = 4, col = 2, min = 0,    max = 208.2,  default = 104.16, mult = 4.807, step = 10, mspapi = 1, apikey = "rates_4"},
            -- Expo
            {row = 1, col = 3, min = 0,    max = 1000,   default = 0,      decimals = 2, scale = 100, mspapi = 1, apikey = "rcExpo_1"},
            {row = 2, col = 3, min = 0,    max = 1000,   default = 0,      decimals = 2, scale = 100, mspapi = 1, apikey = "rcExpo_2"},
            {row = 3, col = 3, min = 0,    max = 1000,   default = 0,      decimals = 2, scale = 100, mspapi = 1, apikey = "rcExpo_3"},
            {row = 4, col = 3, min = 0,    max = 1000,   default = 0,      decimals = 2, scale = 100, mspapi = 1, apikey = "rcExpo_4"}
        }
    }
}

return apidata
