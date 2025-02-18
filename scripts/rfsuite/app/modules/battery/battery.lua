local mspapi = {
    api = {
        [1] = 'BATTERY_CONFIG',
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "Max Cell Voltage", mspapi = 1, apikey="vbatmaxcellvoltage"},
            {t = "Full Cell Voltage", mspapi = 1,  apikey="vbatfullcellvoltage"},
            {t = "Warn Cell Voltage", mspapi = 1,  apikey="vbatwarningcellvoltage"},
            {t = "Min Cell Voltage", mspapi = 1,  apikey="vbatmincellvoltage"},
            {t = "Battery Capacity", mspapi = 1,  apikey="batteryCapacity"},
            {t = "Cell Count", mspapi = 1,  apikey="batteryCellCount"}
        }
    }                 
}


return {
    mspapi = mspapi,
    eepromWrite = true,
    reboot = false,
    title = "Battery",
    API = {},
}
