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
            {t = "Temperature Limit", mspapi = 1, apikey = "temperature_limit"},
            {t = "Current Limit", mspapi = 1, apikey = "current_limit"},
            {t = "Low Voltage Cutoff", mspapi = 1, type = 1, apikey = "low_voltage_cutoff"},
            {t = "Low Voltage Threshold", mspapi = 1, apikey = "low_voltage_threshold"},
            {t = "Servo Low Threshold", mspapi = 1, apikey = "servo_low_threshold"},
            {t = "Servo High Threshold", mspapi = 1, apikey = "servo_high_threshold"},
            {t = "Servo Neutral", mspapi = 1, apikey = "servo_neutral"},
            {t = "Servo Dead Band", mspapi = 1, apikey = "servo_dead_band"},
            {t = "RC Car Reversing", mspapi = 1, type = 1, apikey = "rc_car_reversing"},
            {t = "Use Hall Sensors", mspapi = 1, type = 1, apikey = "use_hall_sensors"},
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
