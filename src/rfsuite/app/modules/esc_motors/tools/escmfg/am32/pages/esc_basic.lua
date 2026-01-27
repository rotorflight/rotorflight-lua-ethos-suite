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
            {t = "@i18n(app.modules.esc_tools.mfg.am32.direction)@", type = 1, mspapi = 1, apikey = "motor_direction"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.motorkv)@", mspapi = 1, apikey = "motor_kv"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.motorpoles)@", mspapi = 1, apikey = "motor_poles"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.startuppower)@", mspapi = 1, apikey = "startup_power"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.complementary_pwm)@", type = 1, mspapi = 1, apikey = "complementary_pwm"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.brakeonstop)@", type = 1, mspapi = 1, apikey = "brake_on_stop"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.brakestrength)@", mspapi = 1, apikey = "brake_strength"},
            {t = "@i18n(app.modules.esc_tools.mfg.am32.runningbrake)@", mspapi = 1, apikey = "running_brake_level"},

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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.basic)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}

