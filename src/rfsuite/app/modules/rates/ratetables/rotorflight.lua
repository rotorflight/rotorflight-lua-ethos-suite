--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local apidata = {
    api = {
        {id = 1, name = "RC_TUNING", enableDeltaCache = false, rebuildOnWrite = true},
    },
    formdata = {
        name = "@i18n(app.modules.rates.rotorflight)@",
        labels = {},
        rows = {"@i18n(app.modules.rates.roll)@", "@i18n(app.modules.rates.pitch)@", "@i18n(app.modules.rates.yaw)@", "@i18n(app.modules.rates.collective)@"},
        cols = {"@i18n(app.modules.rates.rate)@", "@i18n(app.modules.rates.shape)@", "@i18n(app.modules.rates.expo)@"},
        fields = {
            {row = 1, col = 1, min = 0, max = 100, default = 49, mult = 5, step = 5, mspapi = 1, apikey = "rcRates_1"}, 
            {row = 2, col = 1, min = 0, max = 100, default = 48, mult = 5, step = 5, mspapi = 1, apikey = "rcRates_2"}, 
            {row = 3, col = 1, min = 0, max = 100, default = 25, mult = 5, step = 5, mspapi = 1, apikey = "rcRates_3"}, 
            {row = 4, col = 1, min = 0, max = 200, default = 50, mult = 5, decimals = 2, step = 10, scale = 40, mspapi = 1, apikey = "rcRates_4"},

            {row = 1, col = 2, min = 0, max = 127, default = 24, mult = 1, step = 1, mspapi = 1, apikey = "rates_1"}, 
            {row = 2, col = 2, min = 0, max = 127, default = 24, mult = 1, step = 1, mspapi = 1, apikey = "rates_2"}, 
            {row = 3, col = 2, min = 0, max = 127, default = 24, mult = 1, step = 1, mspapi = 1, apikey = "rates_3"}, 
            {row = 4, col = 2, min = 0, max = 127, default = 50, mult = 1, step = 1, mspapi = 1, apikey = "rates_4"},

            {row = 1, col = 3, min = 0, max = 100, default = 0, mspapi = 1, apikey = "rcExpo_1"}, 
            {row = 2, col = 3, min = 0, max = 100, default = 0, mspapi = 1, apikey = "rcExpo_2"},
            {row = 3, col = 3, min = 0, max = 100, default = 0, mspapi = 1, apikey = "rcExpo_3"},
            {row = 4, col = 3, min = 0, max = 100, default = 0, mspapi = 1, apikey = "rcExpo_4"}
        }
    }
}

return apidata
