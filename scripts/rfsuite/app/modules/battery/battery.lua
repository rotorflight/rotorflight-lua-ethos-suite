local i18n = rfsuite.i18n.get

local apidata = {
    api = {
        [1] = 'BATTERY_CONFIG',
        [2] = 'PILOT_CONFIG',   
        [3] = 'BATTERY_FUELCALC_INI'     
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = i18n("app.modules.battery.max_cell_voltage"), mspapi = 1, apikey = "vbatmaxcellvoltage"},
            {t = i18n("app.modules.battery.full_cell_voltage"), mspapi = 1, apikey = "vbatfullcellvoltage"},
            {t = i18n("app.modules.battery.warn_cell_voltage"), mspapi = 1, apikey = "vbatwarningcellvoltage"},
            {t = i18n("app.modules.battery.min_cell_voltage"), mspapi = 1, apikey = "vbatmincellvoltage"},
            {t = i18n("app.modules.battery.battery_capacity"), mspapi = 1, apikey = "batteryCapacity"},
            {t = i18n("app.modules.battery.cell_count"), mspapi = 1, apikey = "batteryCellCount"},
            {t = i18n("app.modules.battery.consumption_warning_percentage"), min = 15, max = 60, mspapi = 1, apikey = "consumptionWarningPercentage"},
            {t = i18n("app.modules.battery.timer"), mspapi = 2, apikey = "model_param1_value"},
            {t = i18n("app.modules.battery.voltage_multiplier"), mspapi = 3, apikey = "sag_multiplier"},
            {t = i18n("app.modules.battery.calcfuel_local"), mspapi = 3, apikey = "calc_local", type = 1},
        }
    }                 
}

local function postLoad(self)
    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "consumptionWarningPercentage" then
            local v = tonumber(f.value)
            if v then
                if v < 15 then
                    f.value = 35
                elseif v > 60 then
                    f.value = 35
                end
            end
        end
    end
    rfsuite.app.triggers.closeProgressLoader = true
end

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    API = {},
    postLoad = postLoad,
}
