

local apidata = {
    api = {
        [1] = 'RC_TUNING',
    },
    formdata = {
        name = "@i18n(app.modules.rates.raceflight)@",
        labels = {
        },
        rows = {
            "@i18n(app.modules.rates.roll)@",
            "@i18n(app.modules.rates.pitch)@",
            "@i18n(app.modules.rates.yaw)@",
            "@i18n(app.modules.rates.collective)@"
        },
        cols = {
            "@i18n(app.modules.rates.rc_rate)@",
            "@i18n(app.modules.rates.acroplus)@",
            "@i18n(app.modules.rates.expo)@"
        },
        fields = {
            -- rc rate
            {row = 1, col = 1, min = 0, max = 100, default = 24, mult = 10, step = 10, mspapi = 1, apikey = "rcRates_1"},
            {row = 2, col = 1, min = 0, max = 100, default = 24, mult = 10, step = 10, mspapi = 1, apikey = "rcRates_2"},
            {row = 3, col = 1, min = 0, max = 100, default = 40, mult = 10, step = 10, mspapi = 1, apikey = "rcRates_3"},
            {row = 4, col = 1, min = 0, max = 100, default = 50, decimals = 1, scale = 4, mspapi = 1, apikey = "rcRates_4"},
            -- acro+
            {row = 1, col = 2, min = 0, max = 255, default = 0, mspapi = 1, apikey = "rates_1"},
            {row = 2, col = 2, min = 0, max = 255, default = 0, mspapi = 1, apikey = "rates_2"},
            {row = 3, col = 2, min = 0, max = 255, default = 0, mspapi = 1, apikey = "rates_3"},
            {row = 4, col = 2, min = 0, max = 255, default = 0, mspapi = 1, apikey = "rates_4"},
            -- expo
            {row = 1, col = 3, min = 0, max = 100, default = 0, mspapi = 1, apikey = "rcExpo_1"},
            {row = 2, col = 3, min = 0, max = 100, default = 0, mspapi = 1, apikey = "rcExpo_2"},
            {row = 3, col = 3, min = 0, max = 100, default = 0, mspapi = 1, apikey = "rcExpo_3"},
            {row = 4, col = 3, min = 0, max = 100, default = 0, mspapi = 1, apikey = "rcExpo_4"}
        }
    }                 
}


return apidata