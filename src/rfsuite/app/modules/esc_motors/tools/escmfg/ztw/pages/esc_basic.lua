--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local folder = "ztw"
local ESC = assert(loadfile("app/modules/esc_motors/tools/escmfg/" .. folder .. "/init.lua"))()
local activeFields = ESC.getActiveFields(rfsuite.session.escBuffer)
local activateWakeup = false

local apidata = {
    api = {[1] = "ESC_PARAMETERS_ZTW"},
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.lv_bec_voltage)@", activeFieldPos =  5, type = 1, mspapi = 1, apikey = "lv_bec_voltage"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.hv_bec_voltage)@", activeFieldPos = 11, type = 1, mspapi = 1, apikey = "hv_bec_voltage"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.motor_direction)@", activeFieldPos =  6, type = 1, mspapi = 1, apikey = "motor_direction"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.startup_power)@", activeFieldPos = 12, type = 1, mspapi = 1, apikey = "startup_power"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.led_color)@", activeFieldPos = 18, type = 1, mspapi = 1, apikey = "led_color"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.smart_fan)@", activeFieldPos = 19, type = 1, mspapi = 1, apikey = "smart_fan"}
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

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_motors/tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, folder, "esc_motors/tools/esc_tool.lua")
        return true
    end

end

local function wakeup(self) if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then activateWakeup = false end end


return {apidata = apidata, eepromWrite = false, reboot = false, escinfo = escinfo, svFlags = 0, postLoad = postLoad, navButtons = {menu = true, save = true, reload = true, tool = false, help = false}, onNavMenu = onNavMenu, event = event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.ztw.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.ztw.basic)@", headerLine = rfsuite.escHeaderLineText, wakeup = wakeup}

