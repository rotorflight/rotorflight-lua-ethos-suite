local apidata = {
    api = {
        [1] = 'BATTERY_CONFIG',
        [2] = 'PILOT_CONFIG',        
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.battery.max_cell_voltage"), mspapi = 1, apikey="vbatmaxcellvoltage"},
            {t = rfsuite.i18n.get("app.modules.battery.full_cell_voltage"), mspapi = 1,  apikey="vbatfullcellvoltage"},
            {t = rfsuite.i18n.get("app.modules.battery.warn_cell_voltage"), mspapi = 1,  apikey="vbatwarningcellvoltage"},
            {t = rfsuite.i18n.get("app.modules.battery.min_cell_voltage"), mspapi = 1,  apikey="vbatmincellvoltage"},
            {t = rfsuite.i18n.get("app.modules.battery.battery_capacity"), mspapi = 1,  apikey="batteryCapacity"},
            {t = rfsuite.i18n.get("app.modules.battery.cell_count"), mspapi = 1,  apikey="batteryCellCount"},
            {t = rfsuite.i18n.get("app.modules.battery.consumption_warning_percentage"), mspapi = 1,  apikey="consumptionWarningPercentage"},
            {t = rfsuite.i18n.get("app.modules.battery.timer"), mspapi = 2,  apikey="model_param1_value"},

        }
    }                 
}

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    API = {},
}
