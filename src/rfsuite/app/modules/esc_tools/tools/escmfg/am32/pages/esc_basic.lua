--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local escToolsPage = assert(loadfile("app/lib/esc_tools_page.lua"))()

local folder = "am32"
local ESC = assert(loadfile("app/modules/esc_tools/tools/escmfg/" .. folder .. "/init.lua"))()

local FIELD_IDX = {
    motor_direction = 1,
    motor_kv = 2,
    motor_poles = 3,
    startup_power = 4,
    brake_on_stop = 5,
    brake_strength = 6,
    running_brake_level = 7,
    beep_volume = 8,
}

local apidata = {
    api = {
        [1] = "ESC_PARAMETERS_AM32",
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELD_IDX.motor_direction] = {t = "Direction", type = 1, mspapi = 1, apikey = "motor_direction"},
            [FIELD_IDX.motor_kv] = {t = "Motor KV", mspapi = 1, apikey = "motor_kv"},
            [FIELD_IDX.motor_poles] = {t = "Motor Poles", mspapi = 1, apikey = "motor_poles"},
            [FIELD_IDX.startup_power] = {t = "Startup Power", mspapi = 1, apikey = "startup_power"},
            [FIELD_IDX.brake_on_stop] = {t = "Brake on Stop", type = 1, mspapi = 1, apikey = "brake_on_stop"},
            [FIELD_IDX.brake_strength] = {t = "Brake Strength", mspapi = 1, apikey = "brake_strength"},
            [FIELD_IDX.running_brake_level] = {t = "Running Brake", mspapi = 1, apikey = "running_brake_level"},
            [FIELD_IDX.beep_volume] = {t = "Beep Volume", mspapi = 1, apikey = "beep_volume"},

        }
    }                 
}

local function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

-- Forward-declared so close() below captures the local rather than a nil
-- global; the assignment happens further down, after escToolsPage is used.
local isolatedSave

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
    pageTitle = "Esc Programing" .. " / " .. "AM32" .. " / " .. "Basic",
    headerLine = rfsuite.escHeaderLineText,
    progressCounter = 0.5
}

