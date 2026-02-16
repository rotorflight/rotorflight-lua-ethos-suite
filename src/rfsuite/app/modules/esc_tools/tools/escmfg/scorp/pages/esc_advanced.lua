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
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.soft_start_time)@",     mspapi = 1, apikey = "soft_start_time"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.runup_time)@",          mspapi = 1, apikey = "runup_time"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.bailout)@",             mspapi = 1, apikey = "bailout"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.gov_proportional)@",    mspapi = 1, apikey = "gov_proportional"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.gov_integral)@",        mspapi = 1, apikey = "gov_integral"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.motor_startup_sound)@", mspapi = 1, apikey = "motor_startup_sound", type = 1}
        }
    }
}


local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.scorp.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.scorp.advanced)@",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "@i18n(app.modules.esc_tools.mfg.scorp.extra_msg_save)@"
}
