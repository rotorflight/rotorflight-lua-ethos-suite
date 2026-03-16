--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "am32"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()
local simulatorResponse = ESC.simulatorResponse
local activateWakeup = false
local lastPwmFrequencyEnabled

local FIELD_IDX = {
    motor_direction = 1,
    motor_kv = 2,
    motor_poles = 3,
    startup_power = 4,
    complementary_pwm = 5,
    variable_pwm_frequency = 6,
    pwm_frequency = 7,
    brake_on_stop = 8,
    brake_strength = 9,
    running_brake_level = 10,
    beep_volume = 11,
}

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_AM32",
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELD_IDX.motor_direction] = {t = "@i18n(app.modules.esc_tools.mfg.am32.direction)@", type = 1, mspapi = 1, apikey = "motor_direction"},
            [FIELD_IDX.motor_kv] = {t = "@i18n(app.modules.esc_tools.mfg.am32.motorkv)@", mspapi = 1, apikey = "motor_kv"},
            [FIELD_IDX.motor_poles] = {t = "@i18n(app.modules.esc_tools.mfg.am32.motorpoles)@", mspapi = 1, apikey = "motor_poles"},
            [FIELD_IDX.startup_power] = {t = "@i18n(app.modules.esc_tools.mfg.am32.startuppower)@", mspapi = 1, apikey = "startup_power"},
            [FIELD_IDX.complementary_pwm] = {t = "@i18n(app.modules.esc_tools.mfg.am32.complementary_pwm)@", type = 1, mspapi = 1, apikey = "complementary_pwm"},
            [FIELD_IDX.variable_pwm_frequency] = {t = "@i18n(app.modules.esc_tools.mfg.am32.variablepwmfrequency)@", mspapi = 1, type = 1, apikey = "variable_pwm_frequency"},            
            [FIELD_IDX.pwm_frequency] = {t = "@i18n(app.modules.esc_tools.mfg.am32.pwmfrequency)@", mspapi = 1, apikey = "pwm_frequency"},
            [FIELD_IDX.brake_on_stop] = {t = "@i18n(app.modules.esc_tools.mfg.am32.brakeonstop)@", type = 1, mspapi = 1, apikey = "brake_on_stop"},
            [FIELD_IDX.brake_strength] = {t = "@i18n(app.modules.esc_tools.mfg.am32.brakestrength)@", mspapi = 1, apikey = "brake_strength"},
            [FIELD_IDX.running_brake_level] = {t = "@i18n(app.modules.esc_tools.mfg.am32.runningbrake)@", mspapi = 1, apikey = "running_brake_level"},
            [FIELD_IDX.beep_volume] = {t = "@i18n(app.modules.esc_tools.mfg.am32.beepvolume)@", mspapi = 1, apikey = "beep_volume"},

        }
    }                 
}

local function postLoad() 
    activateWakeup = true
    lastPwmFrequencyEnabled = nil
    rfsuite.app.triggers.closeProgressLoader = true 
end

local function wakeup()
    if not activateWakeup then return end
    local fields = apidata.formdata.fields
    local variablePwmField = fields and fields[FIELD_IDX.variable_pwm_frequency]
    local pwmFrequencyField = rfsuite.app.formFields and rfsuite.app.formFields[FIELD_IDX.pwm_frequency]
    if not (variablePwmField and pwmFrequencyField and pwmFrequencyField.enable) then
        lastPwmFrequencyEnabled = nil
        return
    end

    local shouldEnable = tonumber(variablePwmField.value) == 1
    if lastPwmFrequencyEnabled ~= shouldEnable then
        pwmFrequencyField:enable(shouldEnable)
        lastPwmFrequencyEnabled = shouldEnable
    end
end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)
local postSave = escToolsPage.createEsc4WayPostSaveHandler(folder, ESC)
local isolatedSave = escToolsPage.createIsolatedSaveMenuHandler(folder, ESC)

local foundEsc = false
local foundEscDone = false

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    simulatorResponse = simulatorResponse,
    postLoad = postLoad,
    postSave = postSave,
    onSaveMenu = isolatedSave and isolatedSave.onSaveMenu or nil,
    close = isolatedSave and isolatedSave.close or nil,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.basic)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5,
    wakeup = wakeup
}

