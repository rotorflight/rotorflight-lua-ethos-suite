local title = "Motor/ESC Features"
local enableWakeup = false

local mspapi = {
    api = {
        [1] = 'MOTOR_CONFIG',
        [2] = 'ESC_SENSOR_CONFIG',
    },
    formdata = {
        labels = {
            {t =  rfsuite.i18n.get("app.modules.esc_motors.main_motor_ratio"), label = 1, inline_size = 15.5},
            {t =  rfsuite.i18n.get("app.modules.esc_motors.tail_motor_ratio"), label = 2, inline_size = 15.5},
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.esc_motors.pinion"),                   api = "MOTOR_CONFIG:main_rotor_gear_ratio_0",    label = 1, inline = 2},
            {t = rfsuite.i18n.get("app.modules.esc_motors.main"),                     api = "MOTOR_CONFIG:main_rotor_gear_ratio_1",    label = 1, inline = 1},
            {t = rfsuite.i18n.get("app.modules.esc_motors.rear"),                     api = "MOTOR_CONFIG:tail_rotor_gear_ratio_0",    label = 2, inline = 2},
            {t = rfsuite.i18n.get("app.modules.esc_motors.front"),                    api = "MOTOR_CONFIG:tail_rotor_gear_ratio_1",    label = 2, inline = 1},
            {t = rfsuite.i18n.get("app.modules.esc_motors.motor_pole_count"),         api = "MOTOR_CONFIG:motor_pole_count_0"},
            {t = rfsuite.i18n.get("app.modules.esc_motors.mincommand"),               api = "MOTOR_CONFIG:mincommand"},
            {t = rfsuite.i18n.get("app.modules.esc_motors.min_throttle"),             api = "MOTOR_CONFIG:minthrottle"},
            {t = rfsuite.i18n.get("app.modules.esc_motors.max_throttle"),             api = "MOTOR_CONFIG:maxthrottle"},
            {t = rfsuite.i18n.get("app.modules.esc_motors.voltage_correction"),       api = "ESC_SENSOR_CONFIG:voltage_correction",    apiversion = 12.08},
            {t = rfsuite.i18n.get("app.modules.esc_motors.current_correction"),       api = "ESC_SENSOR_CONFIG:current_correction",    apiversion = 12.08},
            {t = rfsuite.i18n.get("app.modules.esc_motors.consumption_correction"),   api = "ESC_SENSOR_CONFIG:consumption_correction", apiversion = 12.08}
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
