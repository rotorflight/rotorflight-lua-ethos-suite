--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "blheli_s"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()

local FIELD_IDX = {
    ppm_min_throttle = 1,
    ppm_max_throttle = 2,
    ppm_center_throttle = 3,
}

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_BLHELI_S",
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELD_IDX.ppm_min_throttle] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.ppmminthrottle)@", mspapi = 1, apikey = "ppm_min_throttle"},
            [FIELD_IDX.ppm_max_throttle] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.ppmmaxthrottle)@", mspapi = 1, apikey = "ppm_max_throttle"},
            [FIELD_IDX.ppm_center_throttle] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.ppmcenterthrottle)@", mspapi = 1, apikey = "ppm_center_throttle"},
        }
    }
}

local isolatedSave

local function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local page

local function close(self)
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

    local target = self or page
    if target then
        target.onSaveMenu = nil
        target.postSave = nil
        target.onNavMenu = nil
        target.event = nil
        target.navButtons = nil
        target.headerLine = nil
        target.pageTitle = nil
        target.apidata = nil
        target.close = nil
    end

    isolatedSave = nil
    ESC = nil
    apidata = nil
    page = nil
end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)
local postSave = escToolsPage.createEsc4WayPostSaveHandler(folder, ESC)
isolatedSave = escToolsPage.createIsolatedSaveMenuHandler(folder, ESC)

page = {
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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.blheli_s.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.blheli_s.input)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}

return page
