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
        labels = {},
        fields = {
            { t = "Min Start Power", mspapi = 1, apikey = "min_start_power" },
            { t = "Max Start Power", mspapi = 1, apikey = "max_start_power" },
            { t = "Throttle Response", type = 1, mspapi = 1, apikey = "throttle_response" },
            { t = "Motor Timing", type = 1, mspapi = 1, apikey = "timing" },
            { t = "Active Freewheel", type = 1, mspapi = 1, apikey = "active_freewheel" }
        }
    }
}


local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {apidata = apidata, eepromWrite = true, reboot = false, svTiming = 0, svFlags = 0, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "Esc Programing" .. " / " .. "YGE" .. " / " .. "Advanced", headerLine = rfsuite.escHeaderLineText}
