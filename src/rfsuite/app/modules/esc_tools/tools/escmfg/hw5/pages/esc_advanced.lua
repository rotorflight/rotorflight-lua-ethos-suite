--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()
local hw5Profile = assert(loadfile("app/modules/esc_tools/tools/escmfg/hw5/profile.lua"))()

local folder = "hw5"
local powercycleLoader

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_HW5"
    },
    formdata = {
        labels = {
            {t = "Governor",    label = "gov",    inline_size = 13.4},
            {t = "Soft Start",   label = "start",  inline_size = 40.6},
            {t = "",                                                   label = "start2", inline_size = 40.6},
            {t = "",                                                   label = "start3", inline_size = 40.6},
            {t = "Motor",        label = "motor1", inline_size = 40.6},
            {t = "",                                                   label = "motor2", inline_size = 40.6},
            {t = "",                                                   label = "motor3", inline_size = 40.6},
            {t = "",                                                   label = "motor4", inline_size = 40.6},
            {t = "",                                                   label = "motor5", inline_size = 40.6},
            {t = "Brake",        label = "brake1", inline_size = 40.6},
            {t = "",                                                   label = "brake2", inline_size = 40.6}
        },
        fields = {
            {t = "P-Gain",  inline = 2, label = "gov",    mspapi = 1, apikey = "gov_p_gain"},
            {t = "I-Gain",  inline = 1, label = "gov",    mspapi = 1, apikey = "gov_i_gain"},
            {t = "Startup Time", inline = 1, label = "start",  mspapi = 1, apikey = "startup_time"},
            {t = "Restart Time", inline = 1, label = "start2", mspapi = 1, apikey = "restart_time", type = 1},
            {t = "Auto Restart", inline = 1, label = "start3", mspapi = 1, apikey = "auto_restart"},
            {t = "Timing",           inline = 1, label = "motor1", mspapi = 1, apikey = "timing"},
            {t = "Startup Power",    inline = 1, label = "motor2", type = 1, mspapi = 1, apikey = "startup_power"},
            {t = "Active Freewheel", inline = 1, label = "motor3", type = 1, mspapi = 1, apikey = "active_freewheel"},
            {t = "Response Time",    inline = 1, label = "motor4", type = 1, mspapi = 1, apikey = "response_time"},
            {t = "Rotation",         inline = 1, label = "motor5", type = 1, mspapi = 1, apikey = "rotation"},
            {t = "Brake Type",       inline = 1, label = "brake1", type = 1, mspapi = 1, apikey = "brake_type"},
            {t = "Brake Force%",      inline = 1, label = "brake2", mspapi = 1, apikey = "brake_force"}
        }
    }
}

hw5Profile.configurePage(apidata, "advanced")

local function postLoad()
    hw5Profile.postLoad("advanced")
    rfsuite.app.triggers.closeProgressLoader = true
end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)
return {apidata = apidata, eepromWrite = true, reboot = false, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "Esc Programing" .. " / " .. "Hobbywing V5" .. " / " .. "Advanced", headerLine = rfsuite.escHeaderLineText}
