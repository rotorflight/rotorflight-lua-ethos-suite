local title = "Motor/ESC Features"
local enableWakeup = false

local apiform = {
    mspapi = {'ESC_SENSOR_CONFIG','MOTOR_CONFIG'},
    formdata = {
        labels = {
            {t = "Main Motor Ratio", t2 = "Main Motor Gear Ratio", label = 1, inline_size = 14.5},
            {t = "Tail Motor Ratio", t2 = "Tail Motor Gear Ratio", label = 2, inline_size = 14.5},
            {t = "Port Setup", label=3, inline_size = 17.3},
            {t = "    ", label=4, inline_size = 17.3}
        },
        fields = {
            {t = "Pinion", label = 1, inline = 2, apikey = "main_rotor_gear_ratio_0"},
            {t = "Main", label = 1, inline = 1, apikey = "main_rotor_gear_ratio_1"},
            
            {t = "Rear", label = 2, inline = 2, apikey = "tail_rotor_gear_ratio_0"},
            {t = "Front", label = 2, inline = 1, apikey = "tail_rotor_gear_ratio_1"},
            
            {t = "Motor Pole Count", apikey = "motor_pole_count_0"},
            
            {t = "0% Throttle PWM Value", apikey = "minthrottle"},
            {t = "100% Throttle PWM value", apikey = "maxthrottle"},
            {t = "Motor Stop PWM Value",  apikey = "mincommand"},

            {t = "Protocol", apikey = "protocol", type=1, label=3, inline = 2},
            {t = "Pin Swap", apikey = "pin_swap", type=1, label=3, inline = 1} ,   
            
            {t = "Half Duplex", apikey = "half_duplex", type=1, label=4, inline = 2},
            {t = "Update HZ", apikey = "update_hz", label=4, inline = 1},

            {t = "Current Correction Factor", apikey = "current_correction_factor", apiversion=12.08},
            {t = "Consumption Correction Factor", apikey = "consumption_correction_factor", apiversion=12.08},            
        }
    }                 
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true

end

local function wakeup()
    if enableWakeup == true then

    end
end

return {
    title = title,
    event = event,
    apiform = apiform,
    wakeup = wakeup,
    postLoad = postLoad,
}
