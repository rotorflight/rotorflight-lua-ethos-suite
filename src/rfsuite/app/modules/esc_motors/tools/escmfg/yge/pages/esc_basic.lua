--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()
local folder = "yge"

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_YGE"
    },
    formdata = {
        labels = {
            { t = "@i18n(app.modules.esc_tools.mfg.yge.esc)@", label = "esc1", inline_size = 40.6 },
            { t = "", label = "esc2", inline_size = 40.6 },
            { t = "", label = "esc3", inline_size = 40.6 },
            { t = "", label = "esc4", inline_size = 40.6 },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.limits)@", label = "limits1", inline_size = 40.6 },
            { t = "", label = "limits2", inline_size = 40.6 },
            { t = "", label = "limits3", inline_size = 40.6 }
        },
        fields = {
            { t = "@i18n(app.modules.esc_tools.mfg.yge.esc_mode)@", inline = 1, label = "esc1", type = 1, mspapi = 1, apikey = "governor" },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.direction)@", inline = 1, label = "esc2", type = 1, mspapi = 1, apikey = "flags->direction" },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.lv_bec_voltage)@", inline = 1, label = "esc3", mspapi = 1, apikey = "lv_bec_voltage" },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.f3c_auto)@", inline = 1, label = "esc4", type = 1, mspapi = 1, apikey = "flags->f3cauto" },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.auto_restart_time)@", inline = 1, label = "limits1", type = 1, mspapi = 1, apikey = "auto_restart_time" },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.cell_cutoff)@", inline = 1, label = "limits2", type = 1, mspapi = 1, apikey = "cell_cutoff" },
            { t = "@i18n(app.modules.esc_tools.mfg.yge.current_limit)@", inline = 1, label = "limits3", mspapi = 1, apikey = "current_limit" }
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)


return {apidata = apidata, eepromWrite = false, reboot = false, escinfo = escinfo, svFlags = 0, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.yge.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.yge.basic)@", headerLine = rfsuite.escHeaderLineText}

