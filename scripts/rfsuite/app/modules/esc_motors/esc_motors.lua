local title = "Motor/ESC Features"
local enableWakeup = false

local apiform = {
    mspapi = {
        [1] = 'ESC_SENSOR_CONFIG',
        [2] = 'MOTOR_CONFIG'
    },
    formdata = {
        labels = {
            {t = "Main Motor Ratio", label = 1, inline_size = 14.5},
            {t = "Tail Motor Ratio", label = 2, inline_size = 14.5},
            {t = "Port Setup",       label = 3, inline_size = 17.3},
            {t = "    ",             label = 4, inline_size = 17.3}
        }
        },
        fields = {
            {t = "Pinion",                          label = 1, inline = 2, mspapi = 1, apikey = "main_rotor_gear_ratio_0"},
            {t = "Main",                            label = 1, inline = 1, mspapi = 1, apikey = "main_rotor_gear_ratio_1"},
            {t = "Rear",                            label = 2, inline = 2, mspapi = 1, apikey = "tail_rotor_gear_ratio_0"},
            {t = "Front",                           label = 2, inline = 1, mspapi = 1, apikey = "tail_rotor_gear_ratio_1"},
            {t = "Motor Pole Count",                                       mspapi = 1, apikey = "motor_pole_count_0"},
            {t = "0% Throttle PWM Value",                                  mspapi = 1, apikey = "minthrottle"},
            {t = "100% Throttle PWM value",                                mspapi = 1, apikey = "maxthrottle"},
            {t = "Motor Stop PWM Value",                                   mspapi = 1, apikey = "mincommand"},
            
            {t = "Protocol",                                               mspapi = 2, apikey = "protocol", type = 1, label = 3, inline = 2},
            {t = "Pin Swap",                                               mspapi = 2, apikey = "pin_swap", type = 1, label = 3, inline = 1},
            {t = "Half Duplex",                                            mspapi = 2, apikey = "half_duplex", type = 1, label = 4, inline = 2},
            {t = "Update HZ",                                              mspapi = 2, apikey = "update_hz", label = 4, inline = 1},
            {t = "Current Correction Factor",                              mspapi = 2, apikey = "current_correction_factor", apiversion = 12.08},
            {t = "Consumption Correction Factor",                          mspapi = 2, apikey = "consumption_correction_factor", apiversion = 12.08}
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
