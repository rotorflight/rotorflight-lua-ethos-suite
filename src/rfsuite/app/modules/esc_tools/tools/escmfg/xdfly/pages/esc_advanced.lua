--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()
local folder = "xdfly"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()
local activeFields = ESC.getActiveFields(rfsuite.session.escBuffer)
local activateWakeup = false

local apidata = {
    api = {[1] = "ESC_PARAMETERS_XDFLY"},
    formdata = {
        labels = {},
        fields = {
            {t = "Timing",            activeFieldPos = 4,  mspapi = 1, type = 1, apikey = "timing"},
            {t = "Acceleration",      activeFieldPos = 9,  mspapi = 1, type = 1, apikey = "acceleration"},
            {t = "Brake Force",       activeFieldPos = 14, mspapi = 1,         apikey = "brake_force"},
            {t = "SR Function",        activeFieldPos = 15, mspapi = 1, type = 1, apikey = "sr_function"},
            {t = "Capacity Correction", activeFieldPos = 16, mspapi = 1,         apikey = "capacity_correction"},
            {t = "Auto Restart Time",  activeFieldPos = 10, mspapi = 1, type = 1, apikey = "auto_restart_time"},
            {t = "Cell Cutoff",        activeFieldPos = 11, mspapi = 1, type = 1, apikey = "cell_cutoff"}
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

return {apidata = apidata, eepromWrite = true, reboot = false, svTiming = 0, svFlags = 0, postLoad = postLoad, navButtons = navHandlers.navButtons, onNavMenu = navHandlers.onNavMenu, event = navHandlers.event, pageTitle = "Esc Programing" .. " / " .. "XDFLY" .. " / " .. "Advanced", headerLine = rfsuite.escHeaderLineText, wakeup = wakeup}
