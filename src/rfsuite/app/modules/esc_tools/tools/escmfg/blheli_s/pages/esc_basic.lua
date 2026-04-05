--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "blheli_s"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()

local FIELD_IDX = {
    motor_direction = 1,
    startup_power = 2,
    commutation_timing = 3,
    demag_compensation = 4,
    brake_on_stop = 5,
}

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_BLHELI_S",
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELD_IDX.motor_direction] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.motordirection)@", type = 1, mspapi = 1, apikey = "motor_direction"},
            [FIELD_IDX.startup_power] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.startuppower)@", type = 1, mspapi = 1, apikey = "startup_power"},
            [FIELD_IDX.commutation_timing] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.motortiming)@", type = 1, mspapi = 1, apikey = "commutation_timing"},
            [FIELD_IDX.demag_compensation] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.demagcompensation)@", type = 1, mspapi = 1, apikey = "demag_compensation"},
            [FIELD_IDX.brake_on_stop] = {t = "@i18n(app.modules.esc_tools.mfg.blheli_s.brakeonstop)@", type = 1, mspapi = 1, apikey = "brake_on_stop"},
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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.blheli_s.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.blheli_s.basic)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
