--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local enableWakeup = false
local formFields = rfsuite.app.formFields


local FIELDKEY = {
    PROTOCOL = 1,
    PWM_RATE = 2,
    MINCOMMAND = 3,
    MINTHROTTLE = 4,
    MAXTHROTTLE = 5,
    UNSYNCED = 6
}

local apidata = {
    api = {
        [1] = 'MOTOR_CONFIG',
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELDKEY.PROTOCOL] = {t = "@i18n(app.modules.esc_motors.throttle_protocol)@",      api = "MOTOR_CONFIG:motor_pwm_protocol", type = 1},
            [FIELDKEY.PWM_RATE] = {t = "@i18n(app.modules.esc_motors.motor_pwm_rate)@",         api = "MOTOR_CONFIG:motor_pwm_rate"},
            [FIELDKEY.MINCOMMAND] = {t = "@i18n(app.modules.esc_motors.mincommand)@",           api = "MOTOR_CONFIG:mincommand"},
            [FIELDKEY.MINTHROTTLE] = {t = "@i18n(app.modules.esc_motors.min_throttle)@",        api = "MOTOR_CONFIG:minthrottle"},
            [FIELDKEY.MAXTHROTTLE] = {t = "@i18n(app.modules.esc_motors.max_throttle)@",        api = "MOTOR_CONFIG:maxthrottle"},
            [FIELDKEY.UNSYNCED] = {t = "@i18n(app.modules.esc_motors.unsynced)@",               api = "MOTOR_CONFIG:use_unsynced_pwm", type = 1},
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function wakeup() 
    if not enableWakeup then return end

    local protocolValue = rfsuite.app.Page.apidata.formdata.fields[FIELDKEY.PROTOCOL].value
    if protocolValue == nil then
        protocolValue = 0
    else
        protocolValue = math.floor(protocolValue)
    end

    local unsyncedValue = rfsuite.app.Page.apidata.formdata.fields[FIELDKEY.UNSYNCED].value

    -- if using things like dshot this comes back as nil - and that mangles the form drop downs so reset it to off
    if unsyncedValue == nil then
        rfsuite.app.Page.apidata.formdata.fields[FIELDKEY.UNSYNCED].value = 0
    end

    if protocolValue == 0 then  -- PWM          (PWM_RATE, MINCOMMAND, MINTHROTTLE, MAXTHROTTLE)
        formFields[FIELDKEY.PWM_RATE]:enable(true)
        formFields[FIELDKEY.MINCOMMAND]:enable(true)
        formFields[FIELDKEY.MINTHROTTLE]:enable(true)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(true)
        formFields[FIELDKEY.UNSYNCED]:enable(false)
    elseif(protocolValue == 1)   then  -- ONESHOT125  (PROTOCOL , PWM_RATE, MINCOMMAND, MINTHROTTLE, MAXTHROTTLE, UNSYNCED)
        formFields[FIELDKEY.PWM_RATE]:enable(true)
        formFields[FIELDKEY.MINCOMMAND]:enable(true)
        formFields[FIELDKEY.MINTHROTTLE]:enable(true)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(true)
        formFields[FIELDKEY.UNSYNCED]:enable(true)
    elseif(protocolValue == 2) then  -- ONESHOT 42 (PROTOCOL , PWM_RATE, MINCOMMAND, MINTHROTTLE, MAXTHROTTLE, UNSYNCED)
        formFields[FIELDKEY.PWM_RATE]:enable(true)
        formFields[FIELDKEY.MINCOMMAND]:enable(true)
        formFields[FIELDKEY.MINTHROTTLE]:enable(true)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(true)
        formFields[FIELDKEY.UNSYNCED]:enable(true)
    elseif(protocolValue == 3) then  -- MULTISHOT (PROTOCOL , PWM_RATE, MINCOMMAND, MINTHROTTLE, MAXTHROTTLE, UNSYNCED)
        formFields[FIELDKEY.PWM_RATE]:enable(true)
        formFields[FIELDKEY.MINCOMMAND]:enable(true)
        formFields[FIELDKEY.MINTHROTTLE]:enable(true)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(true)
        formFields[FIELDKEY.UNSYNCED]:enable(true)
    elseif(protocolValue == 4) then  -- BRUSHED (PROTOCOL , PWM_RATE, MINCOMMAND, MINTHROTTLE, MAXTHROTTLE, UNSYNCED)
        formFields[FIELDKEY.PWM_RATE]:enable(true)
        formFields[FIELDKEY.MINCOMMAND]:enable(true)
        formFields[FIELDKEY.MINTHROTTLE]:enable(true)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(true)
        formFields[FIELDKEY.UNSYNCED]:enable(true)        
    elseif(protocolValue == 5) then  -- DSHOT150
        formFields[FIELDKEY.PWM_RATE]:enable(false)
        formFields[FIELDKEY.MINCOMMAND]:enable(false)
        formFields[FIELDKEY.MINTHROTTLE]:enable(false)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(false)
        formFields[FIELDKEY.UNSYNCED]:enable(false)
    elseif(protocolValue == 6) then  -- DSHOT300 
        formFields[FIELDKEY.PWM_RATE]:enable(false)
        formFields[FIELDKEY.MINCOMMAND]:enable(false)
        formFields[FIELDKEY.MINTHROTTLE]:enable(false)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(false)
        formFields[FIELDKEY.UNSYNCED]:enable(false)
    elseif(protocolValue == 7) then  -- DSHOT600
        formFields[FIELDKEY.PWM_RATE]:enable(false)
        formFields[FIELDKEY.MINCOMMAND]:enable(false)
        formFields[FIELDKEY.MINTHROTTLE]:enable(false)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(false)
        formFields[FIELDKEY.UNSYNCED]:enable(false)
    elseif(protocolValue == 8) then  -- PROSHOT
        formFields[FIELDKEY.PWM_RATE]:enable(false)
        formFields[FIELDKEY.MINCOMMAND]:enable(false)
        formFields[FIELDKEY.MINTHROTTLE]:enable(false)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(false)
        formFields[FIELDKEY.UNSYNCED]:enable(false)        
    elseif(protocolValue == 9 and rfsuite.utils.apiVersionCompare(">=", {12, 0, 7})) then  -- CASTLE
        formFields[FIELDKEY.PWM_RATE]:enable(true)
        formFields[FIELDKEY.MINCOMMAND]:enable(true)
        formFields[FIELDKEY.MINTHROTTLE]:enable(true)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(true)
        formFields[FIELDKEY.UNSYNCED]:enable(false)
    else  -- DISABLED
        formFields[FIELDKEY.PWM_RATE]:enable(false)
        formFields[FIELDKEY.MINCOMMAND]:enable(false)
        formFields[FIELDKEY.MINTHROTTLE]:enable(false)
        formFields[FIELDKEY.MAXTHROTTLE]:enable(false)
        formFields[FIELDKEY.UNSYNCED]:enable(false)
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
