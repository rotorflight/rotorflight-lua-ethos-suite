local labels = {}
local fields = {}

local mspapi = {
    api = {
        [1] = 'ACC_TRIM',
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.accelerometer.roll"), mspapi=1, apikey="roll"},
            {t = rfsuite.i18n.get("app.modules.accelerometer.pitch"), mspapi=1,apikey="pitch"}
        }
    }                 
}


return {
    mspapi=mspapi,
    eepromWrite = true,
    reboot = false,
    API = {},
}
