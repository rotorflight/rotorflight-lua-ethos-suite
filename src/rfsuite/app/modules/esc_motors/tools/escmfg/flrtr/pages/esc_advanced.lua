--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_motors/tools/escmfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.auto_restart_time)@", mspapi = 1, apikey = "auto_restart_time"},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.restart_acc)@",        mspapi = 1, apikey = "restart_acc"},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.active_freewheel)@",   mspapi = 1, apikey = "active_freewheel", type = 1},
            {t = "@i18n(app.modules.esc_tools.mfg.flrtr.drive_freq)@",         mspapi = 1, apikey = "drive_freq"}
        }
    }
}

local foundEsc = false
local foundEscDone = false

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

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

return {
    apidata = apidata,
    eepromWrite = true,
    reboot = false,
    escinfo = escinfo,
    svTiming = 0,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.flrtr.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.flrtr.advanced)@",
    headerLine = rfsuite.escHeaderLineText, progressCounter = 0.5
}
