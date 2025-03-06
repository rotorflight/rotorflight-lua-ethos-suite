local title = "Motor/ESC Features"
local enableWakeup = false

local mspapi = {
    api = {
        [1] = 'MOTOR_CONFIG',
        [2] = 'ESC_SENSOR_CONFIG',
    },
    formdata = {
        labels = {
            {t = "Main Motor Ratio", label = 1, inline_size = 15.5},
            {t = "Tail Motor Ratio", label = 2, inline_size = 15.5},
        },
        fields = {
            {t = "Pinion",                            api = "MOTOR_CONFIG:main_rotor_gear_ratio_0",       label = 1, inline = 2},
            {t = "Main",                              api = "MOTOR_CONFIG:main_rotor_gear_ratio_1",       label = 1, inline = 1},
            {t = "Rear",                              api = "MOTOR_CONFIG:tail_rotor_gear_ratio_0",       label = 2, inline = 2},
            {t = "Front",                             api = "MOTOR_CONFIG:tail_rotor_gear_ratio_1",       label = 2, inline = 1},
            {t = "Motor Pole Count",                  api = "MOTOR_CONFIG:motor_pole_count_0"},
            {t = "0% Throttle PWM Value",             api = "MOTOR_CONFIG:minthrottle"},
            {t = "100% Throttle PWM value",           api = "MOTOR_CONFIG:maxthrottle"},
            {t = "Motor Stop PWM Value",              api = "MOTOR_CONFIG:mincommand"},

            {t = "Voltage Correction",                api = "ESC_SENSOR_CONFIG:voltage_correction",            apiversion = 12.08},
            {t = "Current Correction",                api = "ESC_SENSOR_CONFIG:current_correction",            apiversion = 12.08},
            {t = "Consumption Correction",            api = "ESC_SENSOR_CONFIG:consumption_correction",        apiversion = 12.08}
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
