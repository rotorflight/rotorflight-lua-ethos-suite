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
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.protection_delay)@",    mspapi = 1, apikey = "protection_delay"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.cutoff_handling)@",      mspapi = 1, apikey = "cutoff_handling"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.max_temperature)@",      mspapi = 1, apikey = "max_temperature"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.max_current)@",          mspapi = 1, apikey = "max_current"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.min_voltage)@",          mspapi = 1, apikey = "min_voltage"},
            {t = "@i18n(app.modules.esc_tools.mfg.scorp.max_used)@",             mspapi = 1, apikey = "max_used"}
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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.scorp.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.scorp.limits)@",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "@i18n(app.modules.esc_tools.mfg.scorp.extra_msg_save)@"
}
