--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "scorp"

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_SCORPION"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "Soft Start Time",     mspapi = 1, apikey = "soft_start_time"},
            {t = "Runup Time",          mspapi = 1, apikey = "runup_time"},
            {t = "Bailout",             mspapi = 1, apikey = "bailout"},
            {t = "Gov Proportional",    mspapi = 1, apikey = "gov_proportional"},
            {t = "Gov Integral",        mspapi = 1, apikey = "gov_integral"},
            {t = "Motor Startup Sound", mspapi = 1, apikey = "motor_startup_sound", type = 1}
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
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "Esc Programing" .. " / " .. "Scorpion" .. " / " .. "Advanced",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "Please reboot the ESC to apply the changes"
}
