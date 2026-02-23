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
            {t = "@i18n(app.modules.esc_tools.mfg.am32.direction)@", type = 1, mspapi = 1, apikey = "motor_direction"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.motorkv)@", mspapi = 1, apikey = "motor_kv"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.motorpoles)@", mspapi = 1, apikey = "motor_poles"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.startuppower)@", mspapi = 1, apikey = "startup_power"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.pwmfrequency)@", mspapi = 1, apikey = "pwm_frequency"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.complementary_pwm)@", type = 1, mspapi = 1, apikey = "complementary_pwm"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.brakeonstop)@", type = 1, mspapi = 1, apikey = "brake_on_stop"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.brakestrength)@", mspapi = 1, apikey = "brake_strength"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.runningbrake)@", mspapi = 1, apikey = "running_brake_level"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.beepvolume)@", mspapi = 1, apikey = "beep_volume"},

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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.basic)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}

