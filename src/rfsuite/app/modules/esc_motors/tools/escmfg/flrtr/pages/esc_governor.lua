--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_motors/tools/escmfg/" .. folder .. "/init.lua"))()
local simulatorResponse = ESC.simulatorResponse


local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.esc_mode)@",        mspapi = 1, apikey = "esc_mode",        type = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.soft_start)@",      mspapi = 1, apikey = "soft_start"},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.gov_p)@",          mspapi = 1, apikey = "gov_p"},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.gov_i)@",          mspapi = 1, apikey = "gov_i"},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.motor_erpm_max)@", mspapi = 1, apikey = "motor_erpm_max"}
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    postLoad = postLoad,
    simulatorResponse = simulatorResponse, 
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.flrtr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.flrtr.governor)@",
    headerLine = rfsuite.escHeaderLineText, progressCounter = 0.5
}
