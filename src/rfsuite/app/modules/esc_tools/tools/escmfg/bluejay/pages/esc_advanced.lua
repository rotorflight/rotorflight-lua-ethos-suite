--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "bluejay"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()

local FIELD_IDX = {
    temperature_protection = 1,
    beep_strength = 2,
    beacon_strength = 3,
    beacon_delay = 4,
}

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_BLUEJAY",
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELD_IDX.temperature_protection] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.temperatureprotection)@", type = 1, mspapi = 1, apikey = "temperature_protection"},
            [FIELD_IDX.beep_strength] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.beepstrength)@", mspapi = 1, apikey = "beep_strength"},
            [FIELD_IDX.beacon_strength] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.beaconstrength)@", mspapi = 1, apikey = "beacon_strength"},
            [FIELD_IDX.beacon_delay] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.beacondelay)@", type = 1, mspapi = 1, apikey = "beacon_delay"},
        }
    }
}

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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. ESC.toolName .. " / " .. "@i18n(app.modules.esc_tools.mfg.blheli_s.advanced)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
