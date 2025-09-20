

local apidata = {
    api = {
        [1] = "FLIGHT_STATS_INI"
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.stats.totalflighttime)@", mspapi = 1, apikey = "totalflighttime"},
            {t = "@i18n(app.modules.stats.flightcount)@", mspapi = 1, apikey = "flightcount"},
            -- {t = "@i18n(app.modules.stats.lastflighttime)@", mspapi = 1, apikey = "lastflighttime"}, -- turned off as no point editing this?
        }
    }                 
}

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    API = {},
}
