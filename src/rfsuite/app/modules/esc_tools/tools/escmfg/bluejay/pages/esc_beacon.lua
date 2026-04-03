--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "bluejay"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()
local layoutRevision = ESC.getLayoutRevision and ESC.getLayoutRevision(rfsuite.session and rfsuite.session.escBuffer or nil) or nil

local function keepField(minLayout, maxLayout, onlyLayout)
    if layoutRevision == nil then return true end
    if onlyLayout ~= nil then return layoutRevision == onlyLayout end
    if minLayout ~= nil and layoutRevision < minLayout then return false end
    if maxLayout ~= nil and layoutRevision > maxLayout then return false end
    return true
end

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_BLUEJAY",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.beepstrength)@", mspapi = 1, apikey = "beep_strength"},
            {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.beaconstrength)@", mspapi = 1, apikey = "beacon_strength"},
            {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.beacondelay)@", type = 1, mspapi = 1, apikey = "beacon_delay"},
            {t = "Startup Beep", type = 1, mspapi = 1, apikey = "startup_beep", _keep = (layoutRevision == nil) or layoutRevision <= 202 or layoutRevision == 205},
        }
    }
}

for i = #apidata.formdata.fields, 1, -1 do
    local f = apidata.formdata.fields[i]
    if f._keep == false then
        table.remove(apidata.formdata.fields, i)
    else
        f._keep = nil
    end
end

local isolatedSave

local function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function close()
    if isolatedSave then isolatedSave.close() end
    local mspApi = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if mspApi and mspApi.clearEntry then mspApi.clearEntry(ESC.mspapi) end
    local queue = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if queue and queue.removeQueuedBy then
        queue:removeQueuedBy(function(msg) return msg and msg.apiname == ESC.mspapi end)
    end
    if apidata then
        apidata.api_reversed = nil
        apidata.api_by_id = nil
        apidata.retryCount = nil
        apidata.apiState = nil
    end
end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)
local postSave = escToolsPage.createEsc4WayPostSaveHandler(folder, ESC)
isolatedSave = escToolsPage.createIsolatedSaveMenuHandler(folder, ESC)

return {
    apidata = apidata,
    eepromWrite = false,
    reboot = false,
    svFlags = 0,
    postLoad = postLoad,
    postSave = postSave,
    onSaveMenu = isolatedSave and isolatedSave.onSaveMenu or nil,
    close = close,
    navButtons = navHandlers.navButtons,
    onNavMenu = navHandlers.onNavMenu,
    event = navHandlers.event,
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. ESC.toolName .. " / Beacon",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
