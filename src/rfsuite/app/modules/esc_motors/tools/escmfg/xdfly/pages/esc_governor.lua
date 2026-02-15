--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc_motors/tools/escmfg/" .. folder .. "/init.lua"))()
local activeFields = ESC.getActiveFields(rfsuite.session.escBuffer)
local activateWakeup = false


local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_XDFLY"
    },
    formdata = {
        labels = {},
        fields = {
            { t = "@i18n(app.modules.esc_tools.mfg.xdfly.gov)@",      activeFieldPos = 2,  type = 1, mspapi = 1, apikey = "governor" },
            { t = "@i18n(app.modules.esc_tools.mfg.xdfly.gov_p)@",    activeFieldPos = 6,  mspapi = 1, apikey = "gov_p" },
            { t = "@i18n(app.modules.esc_tools.mfg.xdfly.gov_i)@",     activeFieldPos = 7,  mspapi = 1, apikey = "gov_i" },
            { t = "@i18n(app.modules.esc_tools.mfg.xdfly.motor_poles)@", activeFieldPos = 17, mspapi = 1, apikey = "motor_poles" }
        }
    }
}

for i = #apidata.formdata.fields, 1, -1 do
    local f = apidata.formdata.fields[i]
    local fieldIndex = f.activeFieldPos
    if activeFields[fieldIndex] == 0 then table.remove(apidata.formdata.fields, i) end
end

local function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
    activateWakeup = true
end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)

local function wakeup(self) if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then activateWakeup = false end end

return {apidata = apidata, eepromWrite = true, reboot = false, escinfo = escinfo, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.xdfly.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.xdfly.governor)@", headerLine = rfsuite.escHeaderLineText, wakeup = wakeup}
