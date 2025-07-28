local i18n = rfsuite.i18n.get
local enableWakeup = false
local disableMultiplier
local becAlert
local rxBattAlert

local apidata = {
    api = {
        [1] = 'BATTERY_CONFIG',
        [2] = 'BATTERY_INI',
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
            {t = i18n("app.modules.battery.timer"), mspapi = 2, apikey = "flighttime"},
            {t = i18n("app.modules.battery.calcfuel_local"), mspapi = 2, apikey = "calc_local", type = 1},
            {t = i18n("app.modules.battery.kalman_multiplier"), mspapi = 2, apikey = "kalman_multiplier"},   
            {t = i18n("app.modules.battery.voltage_multiplier"), mspapi = 2, apikey = "sag_multiplier"},
            {t = i18n("app.modules.battery.alert_type"), mspapi = 2, apikey = "alert_type", type = 1},
            {t = i18n("app.modules.battery.bec_voltage_alert"), mspapi = 2, apikey = "becalertvalue"},
            {t = i18n("app.modules.battery.rx_voltage_alert"),  mspapi = 2, apikey = "rxalertvalue"},            
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
    enableWakeup = true
end

local function wakeup(self)
        if enableWakeup == false then
            return
        end 


    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "calc_local" then
            local v = tonumber(f.value)
            if v == 1 then
                disableMultiplier = true
            else
                disableMultiplier = false   
            end
        end
    end

    if disableMultiplier == true then
        for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
            if f.apikey == "sag_multiplier" or f.apikey == "kalman_multiplier" then
                rfsuite.app.formFields[i]:enable(true)
            end
        end
    else
        for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
            if f.apikey == "sag_multiplier" or f.apikey == "kalman_multiplier" then
                rfsuite.app.formFields[i]:enable(false)
            end
        end
    end    

    for _, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "alert_type" then
            local b = tonumber(f.value)
            if b == 1 then
                becAlert = true
                rxBattAlert = false
            elseif b == 2 then
                becAlert = false
                rxBattAlert = true
            else
                becAlert = false
                rxBattAlert = false
            end
        end
    end

    for i, f in ipairs(self.fields or (self.apidata and self.apidata.formdata.fields) or {}) do
        if f.apikey == "becalertvalue" then
            rfsuite.app.formFields[i]:enable(becAlert)
        elseif f.apikey == "rxalertvalue" then
            rfsuite.app.formFields[i]:enable(rxBattAlert)
        end
    end
end

return {
    wakeup = wakeup,
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    API = {},
    postLoad = postLoad,
}
