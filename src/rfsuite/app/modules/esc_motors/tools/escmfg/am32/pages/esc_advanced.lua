--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


local folder = "am32"
local ESC = assert(loadfile("app/modules/esc_motors/tools/escmfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse
local activateWakeup = false

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_AM32",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.am32.timing)@",  mspapi = 1, type = 1, apikey = "timing_advance"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.stuckrotorprotection)@",  mspapi = 1, type = 1, apikey = "stuck_rotor_protection"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinusoidalstartup)@",  mspapi = 1, type = 1, apikey = "sinusoidal_startup"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinepowermode)@",  mspapi = 1, apikey = "sine_mode_power"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.sinemoderange)@",  mspapi = 1, apikey = "sine_mode_range"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.bidirectionalmode)@",  mspapi = 1, type = 1, apikey = "bidirectional_mode"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.protocol)@",  mspapi = 1, type = 1, apikey = "esc_protocol"},
        }
    }                 
}

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

local foundEsc = false
local foundEscDone = false

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    simulatorResponse = simulatorResponse,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.advanced)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}

