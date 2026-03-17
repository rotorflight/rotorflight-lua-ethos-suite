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
    timing_advance = 1,
    stuck_rotor_protection = 2,
    sinusoidal_startup = 3,
    sine_mode_power = 4,
    sine_mode_range = 5,
    bidirectional_mode = 6,
    esc_protocol = 7,
    stall_protection = 8,
    interval_telemetry = 9,
    auto_advance = 10,
    complementary_pwm = 11,
    variable_pwm_frequency = 12,
    pwm_frequency = 13,
}

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_AM32",
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELD_IDX.timing_advance] = {t = "@i18n(app.modules.esc_tools.mfg.am32.timing)@",  mspapi = 1, type = 1, apikey = "timing_advance"},
            [FIELD_IDX.stuck_rotor_protection] = {t = "@i18n(app.modules.esc_tools.mfg.am32.stuckrotorprotection)@",  mspapi = 1, type = 1, apikey = "stuck_rotor_protection"},
            [FIELD_IDX.sinusoidal_startup] = {t = "@i18n(app.modules.esc_tools.mfg.am32.sinusoidalstartup)@",  mspapi = 1, type = 1, apikey = "sinusoidal_startup"},
            [FIELD_IDX.sine_mode_power] = {t = "@i18n(app.modules.esc_tools.mfg.am32.sinepowermode)@",  mspapi = 1, apikey = "sine_mode_power"},
            [FIELD_IDX.sine_mode_range] = {t = "@i18n(app.modules.esc_tools.mfg.am32.sinemoderange)@",  mspapi = 1, apikey = "sine_mode_range"},
            [FIELD_IDX.bidirectional_mode] = {t = "@i18n(app.modules.esc_tools.mfg.am32.bidirectionalmode)@",  mspapi = 1, type = 1, apikey = "bidirectional_mode"},
            [FIELD_IDX.esc_protocol] = {t = "@i18n(app.modules.esc_tools.mfg.am32.protocol)@",  mspapi = 1, type = 1, apikey = "esc_protocol"},
            [FIELD_IDX.stall_protection] = {t = "@i18n(app.modules.esc_tools.mfg.am32.stallprotection)@", mspapi = 1, type = 1, apikey = "stall_protection"},
            [FIELD_IDX.interval_telemetry] = {t = "@i18n(app.modules.esc_tools.mfg.am32.telemetryinterval)@", mspapi = 1, type = 1, apikey = "interval_telemetry"},
            [FIELD_IDX.auto_advance] = {t = "@i18n(app.modules.esc_tools.mfg.am32.autoadvance)@", mspapi = 1, type = 1, apikey = "auto_advance"},
            [FIELD_IDX.complementary_pwm] = {t = "@i18n(app.modules.esc_tools.mfg.am32.complementary_pwm)@", type = 1, mspapi = 1, apikey = "complementary_pwm"},
            [FIELD_IDX.variable_pwm_frequency] = {t = "@i18n(app.modules.esc_tools.mfg.am32.variablepwmfrequency)@", mspapi = 1, type = 1, apikey = "variable_pwm_frequency"},
            [FIELD_IDX.pwm_frequency] = {t = "@i18n(app.modules.esc_tools.mfg.am32.pwmfrequency)@", mspapi = 1, apikey = "pwm_frequency"},
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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.advanced)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5,
    wakeup = wakeup
}

