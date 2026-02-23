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

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_AM32",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.am32.timing)@",  mspapi = 1, type = 1, apikey = "timing_advance"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.stuckrotorprotection)@",  mspapi = 1, type = 1, apikey = "stuck_rotor_protection"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinusoidalstartup)@",  mspapi = 1, type = 1, apikey = "sinusoidal_startup"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinepowermode)@",  mspapi = 1, apikey = "sine_mode_power"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinemoderange)@",  mspapi = 1, apikey = "sine_mode_range"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.bidirectionalmode)@",  mspapi = 1, type = 1, apikey = "bidirectional_mode"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.protocol)@",  mspapi = 1, type = 1, apikey = "esc_protocol"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.variablepwmfrequency)@", mspapi = 1, type = 1, apikey = "variable_pwm_frequency"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.stallprotection)@", mspapi = 1, type = 1, apikey = "stall_protection"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.telemetryinterval)@", mspapi = 1, type = 1, apikey = "interval_telemetry"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.autoadvance)@", mspapi = 1, type = 1, apikey = "auto_advance"},
        }
    }                 
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

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
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.advanced)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}

