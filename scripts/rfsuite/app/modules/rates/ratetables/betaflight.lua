local mspapi = {
    api = {
        [1] = 'RC_TUNING',
    },
    formdata = {
        name = rfsuite.i18n.get("app.modules.rates.betaflight"),
        labels = {
        },
        rows = {
            rfsuite.i18n.get("app.modules.rates.roll"),
            rfsuite.i18n.get("app.modules.rates.pitch"),
            rfsuite.i18n.get("app.modules.rates.yaw"),
            rfsuite.i18n.get("app.modules.rates.collective")
        },
        cols = {
            rfsuite.i18n.get("app.modules.rates.rc_rate"),
            rfsuite.i18n.get("app.modules.rates.superrate"),
            rfsuite.i18n.get("app.modules.rates.expo")
        },
        fields = {
            -- rc rate
            {row = 1, col = 1, min = 0, max = 255, default = 120, decimals = 2, scale = 100, mspapi = 1, apikey = "rcRates_1"},
            {row = 2, col = 1, min = 0, max = 255, default = 120, decimals = 2, scale = 100, mspapi = 1, apikey = "rcRates_2"},
            {row = 3, col = 1, min = 0, max = 255, default = 200, decimals = 2, scale = 100, mspapi = 1, apikey = "rcRates_3"},
            {row = 4, col = 1, min = 0, max = 220, default = 203, decimals = 2, scale = 100, mspapi = 1, apikey = "rcRates_4"},
            -- super rate
            {row = 1, col = 2, min = 0, max = 99, default = 0,   decimals = 2, scale = 100, mspapi = 1, apikey = "rates_1"},
            {row = 2, col = 2, min = 0, max = 99, default = 0,   decimals = 2, scale = 100, mspapi = 1, apikey = "rates_2"},
            {row = 3, col = 2, min = 0, max = 99, default = 0,   decimals = 2, scale = 100, mspapi = 1, apikey = "rates_3"},
            {row = 4, col = 2, min = 0, max = 99, default = 1,   decimals = 2, scale = 100, mspapi = 1, apikey = "rates_4"},
            -- expo
            {row = 1, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0,   mspapi = 1, apikey = "rcExpo_1"},
            {row = 2, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0,   mspapi = 1, apikey = "rcExpo_2"},
            {row = 3, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0,   mspapi = 1, apikey = "rcExpo_3"},
            {row = 4, col = 3, min = 0, max = 100, decimals = 2, scale = 100, default = 0,   mspapi = 1, apikey = "rcExpo_4"}
        }
    }                 
}


return mspapi

