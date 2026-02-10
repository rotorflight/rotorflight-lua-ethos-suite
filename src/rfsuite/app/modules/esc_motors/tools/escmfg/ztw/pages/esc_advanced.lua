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
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.timing)@",          activeFieldPos = 4,  mspapi = 1, type = 1, apikey = "timing"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.acceleration)@",    activeFieldPos = 9,  mspapi = 1, type = 1, apikey = "acceleration"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.brake_force)@",     activeFieldPos = 14, mspapi = 1,         apikey = "brake_force"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.sr_function)@",      activeFieldPos = 15, mspapi = 1, type = 1, apikey = "sr_function"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.capacity_correction)@", activeFieldPos = 16, mspapi = 1, apikey = "capacity_correction"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.auto_restart_time)@", activeFieldPos = 10, mspapi = 1, type = 1, apikey = "auto_restart_time"},
            {t = "@i18n(app.modules.esc_tools.mfg.ztw.cell_cutoff)@",      activeFieldPos = 11, mspapi = 1, type = 1, apikey = "cell_cutoff"}
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
    rfsuite.app.ui.openPage({idx = pidx, title = folder, script = "esc_motors/tools/esc_tool.lua"})
end

local function event(widget, category, value, x, y)

    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage({idx = pidx, title = folder, script = "esc_motors/tools/esc_tool.lua"})
        return true
    end

end

local function wakeup(self) if activateWakeup == true and rfsuite.tasks.msp.mspQueue:isProcessed() then activateWakeup = false end end

return {apidata = apidata, eepromWrite = true, reboot = false, escinfo = escinfo, svTiming = 0, svFlags = 0, postLoad = postLoad, navButtons = {menu = true, save = true, reload = true, tool = false, help = false}, onNavMenu = onNavMenu, event = event, pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.ztw.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.ztw.advanced)@", headerLine = rfsuite.escHeaderLineText, wakeup = wakeup}
