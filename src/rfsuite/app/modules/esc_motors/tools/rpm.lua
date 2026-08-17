--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

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
            {t = "Main Motor Ratio",    label = 1, inline_size = 15.5},
            {t = "Tail Motor Ratio",    label = 2, inline_size = 15.5}            
        },
        fields = {
            [FIELDS.RPM_SENSOR] = {t = "RPM Sensor",   api = "FEATURE_CONFIG:enabledFeatures->freq_sensor", type = 1, onChange=rpmSensor},
            [FIELDS.DSHOT_TELEMETRY] = {t = "DShot RPM Telemetry", api = "MOTOR_CONFIG:use_dshot_telemetry", type = 1, onChange=dshotSensor},
            [FIELDS.MAIN_PINION] = {t = "Pinion",              api = "MOTOR_CONFIG:main_rotor_gear_ratio_0" , label = 1, inline = 2},
            [FIELDS.MAIN_GEAR] = {t = "Main",                api = "MOTOR_CONFIG:main_rotor_gear_ratio_1" , label = 1, inline = 1},
            [FIELDS.TAIL_PINION] = {t = "Rear",                api = "MOTOR_CONFIG:tail_rotor_gear_ratio_0", label = 2, inline = 2},
            [FIELDS.TAIL_GEAR] = {t = "Front",               api = "MOTOR_CONFIG:tail_rotor_gear_ratio_1", label = 2, inline = 1},
            [FIELDS.MOTOR_POLE_COUNT] = {t = "Motor Pole Count",    api = "MOTOR_CONFIG:motor_pole_count_0"},
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function wakeup() 
    if enableWakeup == true then
        local values = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata and rfsuite.tasks.msp.api.apidata.values
        local motorConfig = values and values["MOTOR_CONFIG"] or nil
        local protocol = motorConfig and motorConfig.motor_pwm_protocol or nil
        local dshotField = formFields and formFields[FIELDS.DSHOT_TELEMETRY] or nil

        if protocol == nil or not (dshotField and dshotField.enable) then
            return
        end

        if protocol >= 5 and protocol <= 8 then
            -- dshot compatable
            dshotField:enable(true)
        else
            -- not dshot
            dshotField:enable(false)
        end

        -- No additional processing for motor protocol here.
    end 
end

local function onNavMenu(self)
    pageRuntime.openMenuContext({defaultSection = "hardware"})
    return true
end

local function event(_, category, value)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

return {apidata = apidata, reboot = true, eepromWrite = true, event = event, wakeup = wakeup, postLoad = postLoad, onNavMenu = onNavMenu}
