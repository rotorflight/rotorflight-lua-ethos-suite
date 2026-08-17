--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()
local simulatorResponse = ESC.simulatorResponse

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "LiPo Cell Count",                   mspapi = 1, apikey = "cell_count"},
            {t = "Low Voltage Limit",        mspapi = 1, apikey = "low_voltage_protection"},
            {t = "Temperature Limit",        mspapi = 1, apikey = "temperature_protection"},
            {t = "SBEC Voltage",                   mspapi = 1, apikey = "bec_voltage",           type = 1},
            {t = "Electrical Angle",              mspapi = 1, apikey = "electrical_angle",       type = 1},
            {t = "Motor Direction",               mspapi = 1, apikey = "motor_direction",        type = 1},
            {t = "Starting Power",               mspapi = 1, apikey = "starting_torque"},
            {t = "Response Speed",                mspapi = 1, apikey = "response_speed"},
            {t = "Beeper Volume",                 mspapi = 1, apikey = "buzzer_volume"},
            {t = "Current Gain",                  mspapi = 1, apikey = "current_gain"},
            {t = "Cooling Fan Mode",                   mspapi = 1, apikey = "fan_control",            type = 1}
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)


return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    svFlags = 0,
    simulatorResponse = simulatorResponse,
    postLoad = postLoad,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "Esc Programing" .. " / " .. "FLYROTOR" .. " / " .. "General",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
