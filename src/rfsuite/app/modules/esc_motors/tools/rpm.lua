--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false

local function rpmSensor(field, value)
    --print("RPM Sensor Source changed to: " .. tostring(value))
end

local function dshotSensor(field, value)
    --print("RPM Sensor Source changed to: " .. tostring(value))
end

local formFields = rfsuite.app.formFields

local FIELDS = {
    RPM_SENSOR = 1,
    DSHOT_TELEMETRY = 2,
    MAIN_PINION = 3,
    MAIN_GEAR = 4,
    TAIL_PINION = 5,
    TAIL_GEAR = 6,
    MOTOR_POLE_COUNT = 7
}

local apidata = {
    api = {
        [1] = 'MOTOR_CONFIG',
        [2] = 'FEATURE_CONFIG'
    },
    formdata = {
        labels = {
            {t = "@i18n(app.modules.esc_motors.main_motor_ratio)@",    label = 1, inline_size = 15.5},
            {t = "@i18n(app.modules.esc_motors.tail_motor_ratio)@",    label = 2, inline_size = 15.5}            
        },
        fields = {
            [FIELDS.RPM_SENSOR] = {t = "@i18n(app.modules.esc_motors.rpm_sensor_source)@",   api = "FEATURE_CONFIG:enabledFeatures->freq_sensor", type = 1, onChange=rpmSensor},
            [FIELDS.DSHOT_TELEMETRY] = {t = "@i18n(app.modules.esc_motors.use_dshot_telemetry)@", api = "MOTOR_CONFIG:use_dshot_telemetry", type = 1, onChange=dshotSensor},
            [FIELDS.MAIN_PINION] = {t = "@i18n(app.modules.esc_motors.pinion)@",              api = "MOTOR_CONFIG:main_rotor_gear_ratio_0" , label = 1, inline = 2},
            [FIELDS.MAIN_GEAR] = {t = "@i18n(app.modules.esc_motors.main)@",                api = "MOTOR_CONFIG:main_rotor_gear_ratio_1" , label = 1, inline = 1},
            [FIELDS.TAIL_PINION] = {t = "@i18n(app.modules.esc_motors.rear)@",                api = "MOTOR_CONFIG:tail_rotor_gear_ratio_0", label = 2, inline = 2},
            [FIELDS.TAIL_GEAR] = {t = "@i18n(app.modules.esc_motors.front)@",               api = "MOTOR_CONFIG:tail_rotor_gear_ratio_1", label = 2, inline = 1},
            [FIELDS.MOTOR_POLE_COUNT] = {t = "@i18n(app.modules.esc_motors.motor_pole_count)@",    api = "MOTOR_CONFIG:motor_pole_count_0"},
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function wakeup() 
    if enableWakeup == true then
        if rfsuite.tasks.msp.api.apidata.values["MOTOR_CONFIG"].motor_pwm_protocol >=5 and rfsuite.tasks.msp.api.apidata.values["MOTOR_CONFIG"].motor_pwm_protocol <= 8 then
            -- dshot compatable
            formFields[FIELDS.DSHOT_TELEMETRY]:enable(true)
        else
            -- not dshot
            formFields[FIELDS.DSHOT_TELEMETRY]:enable(false)
        end

        -- No additional processing for motor protocol here.
    end 
end

local function onNavMenu(self)
    rfsuite.app.ui.openPage(pidx, title, "esc_motors/esc_motors.lua")
end

return {apidata = apidata, reboot = true, eepromWrite = true, title = title, event = event, wakeup = wakeup, postLoad = postLoad, onNavMenu = onNavMenu}
