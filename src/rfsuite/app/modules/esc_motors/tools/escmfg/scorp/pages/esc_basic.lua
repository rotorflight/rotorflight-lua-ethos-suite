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
            { t = "@i18n(app.modules.esc_tools.mfg.scorp.esc_mode)@",      type = 1, mspapi = 1, apikey = "esc_mode" },
            { t = "@i18n(app.modules.esc_tools.mfg.scorp.rotation)@",      type = 1, mspapi = 1, apikey = "rotation" },
            { t = "@i18n(app.modules.esc_tools.mfg.scorp.bec_voltage)@",   type = 1, mspapi = 1, apikey = "bec_voltage" }
        }
    }
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    title = "Basic Setup",
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.scorp.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.scorp.basic)@",
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = "@i18n(app.modules.esc_tools.mfg.scorp.extra_msg_save)@"
}
