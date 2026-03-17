--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "am32"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()

local FIELD_IDX = {
    temperature_limit     = 1,
    current_limit         = 2,
    low_voltage_cutoff    = 3,
    low_voltage_threshold = 4,
    servo_low_threshold   = 5,
    servo_high_threshold  = 6,
    servo_neutral         = 7,
    servo_dead_band       = 8,
    rc_car_reversing      = 9,
    use_hall_sensors      = 10,
}

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_AM32",
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELD_IDX.temperature_limit]     = {t = "@i18n(app.modules.esc_tools.mfg.am32.temperaturelimit)@", mspapi = 1, apikey = "temperature_limit"},
            [FIELD_IDX.current_limit]         = {t = "@i18n(app.modules.esc_tools.mfg.am32.currentlimit)@", mspapi = 1, apikey = "current_limit"},
            [FIELD_IDX.low_voltage_cutoff]    = {t = "@i18n(app.modules.esc_tools.mfg.am32.lowvoltagecutoff)@", mspapi = 1, type = 1, apikey = "low_voltage_cutoff"},
            [FIELD_IDX.low_voltage_threshold] = {t = "@i18n(app.modules.esc_tools.mfg.am32.lowvoltagethreshold)@", mspapi = 1, apikey = "low_voltage_threshold"},
            [FIELD_IDX.servo_low_threshold]   = {t = "@i18n(app.modules.esc_tools.mfg.am32.servolowthreshold)@", mspapi = 1, apikey = "servo_low_threshold"},
            [FIELD_IDX.servo_high_threshold]  = {t = "@i18n(app.modules.esc_tools.mfg.am32.servohighthreshold)@", mspapi = 1, apikey = "servo_high_threshold"},
            [FIELD_IDX.servo_neutral]         = {t = "@i18n(app.modules.esc_tools.mfg.am32.servoneutral)@", mspapi = 1, apikey = "servo_neutral"},
            [FIELD_IDX.servo_dead_band]       = {t = "@i18n(app.modules.esc_tools.mfg.am32.servodeadband)@", mspapi = 1, apikey = "servo_dead_band"},
            [FIELD_IDX.rc_car_reversing]      = {t = "@i18n(app.modules.esc_tools.mfg.am32.rcarreversing)@", mspapi = 1, type = 1, apikey = "rc_car_reversing"},
            [FIELD_IDX.use_hall_sensors]      = {t = "@i18n(app.modules.esc_tools.mfg.am32.usehallsensors)@", mspapi = 1, type = 1, apikey = "use_hall_sensors"},
        }
    }                 
}

local function postLoad() rfsuite.app.triggers.closeProgressLoader = true end

local navHandlers = escToolsPage.createSubmenuHandlers(folder)
local postSave = escToolsPage.createEsc4WayPostSaveHandler(folder, ESC)
local isolatedSave = escToolsPage.createIsolatedSaveMenuHandler(folder, ESC)

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
        apidata.api_by_id    = nil
        apidata.retryCount   = nil
        apidata.apiState     = nil
    end
end

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
    pageTitle = "@i18n(app.modules.esc_tools.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.name)@" .. " / " .. "@i18n(app.modules.esc_tools.mfg.am32.limits)@",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}
