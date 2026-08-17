--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()
local folder = "flrtr"

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "Auto Bailout Time", mspapi = 1, apikey = "auto_restart_time"},
            {t = "Auto Bailout Accel",        mspapi = 1, apikey = "restart_acc"},
            {t = "Active Freewheeling",   mspapi = 1, apikey = "active_freewheel", type = 1},
            {t = "Drive Frequency",         mspapi = 1, apikey = "drive_freq"}
        }
    }
}


local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
        svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "Esc Programing" .. " / " .. "FLYROTOR" .. " / " .. "Advanced",
    headerLine = rfsuite.escHeaderLineText, progressCounter = 0.5
}
