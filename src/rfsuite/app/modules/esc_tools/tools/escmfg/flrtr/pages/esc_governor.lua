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
            {t = "ESC Mode",        mspapi = 1, apikey = "esc_mode",        type = 1},
            {t = "Soft Start Time",      mspapi = 1, apikey = "soft_start"},
            {t = "Governor P",          mspapi = 1, apikey = "gov_p"},
            {t = "Governor I",          mspapi = 1, apikey = "gov_i"},
            {t = "Maximum Motor ERPM", mspapi = 1, apikey = "motor_erpm_max"}
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
        postLoad = postLoad,
    simulatorResponse = simulatorResponse, 
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "Esc Programing" .. " / " .. "FLYROTOR" .. " / " .. "Governor",
    headerLine = rfsuite.escHeaderLineText, progressCounter = 0.5
}
