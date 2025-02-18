local title = "Motor/ESC Features"
local enableWakeup = false

local mspapi = {
    api = {
        [1] = 'MOTOR_CONFIG',
        [2] = 'ESC_SENSOR_CONFIG',
    },
    formdata = {
        labels = {
            {t = "Main Motor Ratio", label = 1, inline_size = 14.5},
            {t = "Tail Motor Ratio", label = 2, inline_size = 14.5},
            {t = "Port Setup",       label = 3, inline_size = 17.3},
            {t = "    ",             label = 4, inline_size = 17.3}
        },
        fields = {
            {t = "ESC Update frequency",            mspapi = 1, apikey = "motor_pwm_rate"},   
            {t = "Pinion",                          mspapi = 1, apikey = "main_rotor_gear_ratio_0",       label = 1, inline = 2},
            {t = "Main",                            mspapi = 1, apikey = "main_rotor_gear_ratio_1",       label = 1, inline = 1},
            {t = "Rear",                            mspapi = 1, apikey = "tail_rotor_gear_ratio_0",       label = 2, inline = 2},
            {t = "Front",                           mspapi = 1, apikey = "tail_rotor_gear_ratio_1",       label = 2, inline = 1},
            {t = "Motor Pole Count",                mspapi = 1, apikey = "motor_pole_count_0"},
            {t = "0% Throttle PWM Value",           mspapi = 1, apikey = "minthrottle"},
            {t = "100% Throttle PWM value",         mspapi = 1, apikey = "maxthrottle"},
            {t = "Motor Stop PWM Value",            mspapi = 1, apikey = "mincommand"},

            {t = "Protocol",                        mspapi = 2, apikey = "protocol",                      type = 1, label = 3, inline = 2},
            {t = "Pin Swap",                        mspapi = 2, apikey = "pin_swap",                      type = 1, label = 3, inline = 1},
            {t = "Half Duplex",                     mspapi = 2, apikey = "half_duplex",                   type = 1, label = 4, inline = 2},
            {t = "Update HZ",                       mspapi = 2, apikey = "update_hz",                     label = 4, inline = 1},
            {t = "Current Correction Factor",       mspapi = 2, apikey = "current_correction_factor",     apiversion = 12.08},
            {t = "Consumption Correction Factor",   mspapi = 2, apikey = "consumption_correction_factor", apiversion = 12.08}
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
    mspapi = mspapi,
    reboot = false,
    eepromWrite = true,    
    title = title,
    event = event,
    wakeup = wakeup,
    postLoad = postLoad,
}
