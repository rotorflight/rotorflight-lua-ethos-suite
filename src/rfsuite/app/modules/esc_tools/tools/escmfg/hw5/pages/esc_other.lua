--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "hw5"
local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_HW5"
    },
    formdata = {
        labels = {
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.motor)@",        label = "motor1", inline_size = 40.6},
            {t = "",                                                     label = "motor2", inline_size = 40.6},
            {t = "",                                                     label = "motor3", inline_size = 40.6},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.brake)@",         label = "brake1", inline_size = 40.6},
            {t = "",                                                     label = "brake2", inline_size = 40.6}
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.timing)@",           inline = 1, label = "motor1", mspapi = 1, apikey = "timing"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.startup_power)@",    inline = 1, label = "motor2", type = 1, mspapi = 1, apikey = "startup_power"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.active_freewheel)@", inline = 1, label = "motor3", type = 1, mspapi = 1, apikey = "active_freewheel"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.brake_type)@",       inline = 1, label = "brake1", type = 1, mspapi = 1, apikey = "brake_type"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.brake_force)@",      inline = 1, label = "brake2", mspapi = 1, apikey = "brake_force"}
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {apidata = apidata, eepromWrite = true, reboot = false, escinfo = escinfo, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.hw5.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.hw5.other)@", headerLine = rfsuite.escHeaderLineText}
