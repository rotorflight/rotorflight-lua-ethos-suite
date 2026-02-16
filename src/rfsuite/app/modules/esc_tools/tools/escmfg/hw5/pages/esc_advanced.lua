--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "hw5"
local powercycleLoader

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_HW5"
    },
    formdata = {
        labels = {
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.governor)@",    label = "gov",    inline_size = 13.4},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.soft_start)@",   label = "start",  inline_size = 40.6},
            {t = "",                                                   label = "start2", inline_size = 40.6},
            {t = "",                                                   label = "start3", inline_size = 40.6}
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.gov_p_gain)@",  inline = 2, label = "gov",    mspapi = 1, apikey = "gov_p_gain"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.gov_i_gain)@",  inline = 1, label = "gov",    mspapi = 1, apikey = "gov_i_gain"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.startup_time)@", inline = 1, label = "start",  mspapi = 1, apikey = "startup_time"},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.restart_time)@", inline = 1, label = "start2", mspapi = 1, apikey = "restart_time", type = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.hw5.auto_restart)@", inline = 1, label = "start3", mspapi = 1, apikey = "auto_restart"}
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)
return {apidata = apidata, eepromWrite = true, reboot = false, escinfo = escinfo, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.hw5.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.hw5.advanced)@", headerLine = rfsuite.escHeaderLineText}
