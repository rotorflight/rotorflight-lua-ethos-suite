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
            {t = "Protection Delay",    mspapi = 1, apikey = "protection_delay"},
            {t = "Cutoff Handling",      mspapi = 1, apikey = "cutoff_handling"},
            {t = "Max Temperature",      mspapi = 1, apikey = "max_temperature"},
            {t = "Max Current",          mspapi = 1, apikey = "max_current"},
            {t = "Min Voltage",          mspapi = 1, apikey = "min_voltage"},
            {t = "Max Used",             mspapi = 1, apikey = "max_used"}
        }
    }
}


local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    title = "Limits",
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "Esc Programing" .. " / " .. "Scorpion" .. " / " .. "Limits",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "Please reboot the ESC to apply the changes"
}
