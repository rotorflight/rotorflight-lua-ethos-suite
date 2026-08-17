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
            { t = "ESC", label = "esc1", inline_size = 40.6 },
            { t = "", label = "esc2", inline_size = 40.6 },
            { t = "", label = "esc3", inline_size = 40.6 },
            { t = "", label = "esc4", inline_size = 40.6 },
            { t = "Limits", label = "limits1", inline_size = 40.6 },
            { t = "", label = "limits2", inline_size = 40.6 },
            { t = "", label = "limits3", inline_size = 40.6 }
        },
        fields = {
            { t = "ESC Mode", inline = 1, label = "esc1", type = 1, mspapi = 1, apikey = "governor" },
            { t = "Direction", inline = 1, label = "esc2", type = 1, mspapi = 1, apikey = "flags->direction" },
            { t = "BEC", inline = 1, label = "esc3", mspapi = 1, apikey = "lv_bec_voltage" },
            { t = "F3C Autorotation", inline = 1, label = "esc4", type = 1, mspapi = 1, apikey = "flags->f3cauto" },
            { t = "Auto Restart Time", inline = 1, label = "limits1", type = 1, mspapi = 1, apikey = "auto_restart_time" },
            { t = "Cell Cutoff", inline = 1, label = "limits2", type = 1, mspapi = 1, apikey = "cell_cutoff" },
            { t = "Current Limit", inline = 1, label = "limits3", mspapi = 1, apikey = "current_limit" }
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)


return {apidata = apidata, eepromWrite = false, reboot = false, svFlags = 0, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "Esc Programing" .. " / " .. "YGE" .. " / " .. "Basic", headerLine = rfsuite.escHeaderLineText}

