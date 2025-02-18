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
            {t = "Roll", mspapi=1, apikey="roll"},
            {t = "Pitch", mspapi=1,apikey="pitch"}
        }
    }                 
}


return {
    mspapi=mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Accelerometer",
    API = {},
}
