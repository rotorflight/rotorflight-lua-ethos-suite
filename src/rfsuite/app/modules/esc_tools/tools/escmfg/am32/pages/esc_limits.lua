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
            {t = "@i18n(app.modules.esc_tools.mfg.am32.temperaturelimit)@", mspapi = 1, apikey = "temperature_limit"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.currentlimit)@", mspapi = 1, apikey = "current_limit"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.lowvoltagecutoff)@", mspapi = 1, type = 1, apikey = "low_voltage_cutoff"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.lowvoltagethreshold)@", mspapi = 1, apikey = "low_voltage_threshold"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.servolowthreshold)@", mspapi = 1, apikey = "servo_low_threshold"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.servohighthreshold)@", mspapi = 1, apikey = "servo_high_threshold"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.servoneutral)@", mspapi = 1, apikey = "servo_neutral"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.servodeadband)@", mspapi = 1, apikey = "servo_dead_band"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.rcarreversing)@", mspapi = 1, type = 1, apikey = "rc_car_reversing"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.usehallsensors)@", mspapi = 1, type = 1, apikey = "use_hall_sensors"},
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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.limits)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
