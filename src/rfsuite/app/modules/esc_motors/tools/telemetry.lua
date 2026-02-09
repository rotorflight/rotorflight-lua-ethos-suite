--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false
local formFields = rfsuite.app.formFields

local FIELDKEY = {
    PROTOCOL = 1,
    HALF_DUPLEX = 2,
    PIN_SWAP = 3,
    VOLTAGE_CORRECTION = 4,
    CURRENT_CORRECTION = 5,
    CONSUMPTION_CORRECTION = 6
}


local apidata = {
    api = {
        [1] = 'ESC_SENSOR_CONFIG'
    },
    formdata = {
        labels = {
        },
        fields = {
            [FIELDKEY.PROTOCOL] = {t = "@i18n(app.modules.esc_motors.telemetry_protocol)@",  api = "ESC_SENSOR_CONFIG:protocol",      apiversion = 12.06, type = 1},
            [FIELDKEY.HALF_DUPLEX] = {t = "@i18n(app.modules.esc_motors.half_duplex)@",  api = "ESC_SENSOR_CONFIG:half_duplex",      apiversion = 12.06, type = 1},
            [FIELDKEY.PIN_SWAP] = {t = "@i18n(app.modules.esc_motors.pin_swap)@",  api = "ESC_SENSOR_CONFIG:pin_swap",      apiversion = 12.06, type = 1},            
            [FIELDKEY.VOLTAGE_CORRECTION] = {t = "@i18n(app.modules.esc_motors.voltage_correction)@",  api = "ESC_SENSOR_CONFIG:voltage_correction",    apiversion = 12.08},
            [FIELDKEY.CURRENT_CORRECTION] = {t = "@i18n(app.modules.esc_motors.current_correction)@",  api = "ESC_SENSOR_CONFIG:current_correction",    apiversion = 12.08},
            [FIELDKEY.CONSUMPTION_CORRECTION] = {t = "@i18n(app.modules.esc_motors.consumption_correction)@", api = "ESC_SENSOR_CONFIG:consumption_correction", apiversion = 12.08}
        }
    }
}

local function postLoad(self)
    rfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function onNavMenu(self)
    rfsuite.app.ui.openPage(pidx, title, "esc_motors/esc_motors.lua")
end

local function wakeup() 
    if not enableWakeup then return end

    local protocolValue = rfsuite.app.Page.apidata.formdata.fields[FIELDKEY.PROTOCOL].value
    if protocolValue == nil then
        protocolValue = 0
    else
        protocolValue = math.floor(protocolValue)
    end


    if protocolValue == 0 then  -- NONE
        formFields[FIELDKEY.HALF_DUPLEX]:enable(false)
        formFields[FIELDKEY.PIN_SWAP]:enable(false)
        if rfsuite.utils.apiVersionCompare(">=", "12.08") then
            formFields[FIELDKEY.VOLTAGE_CORRECTION]:enable(false)
            formFields[FIELDKEY.CURRENT_CORRECTION]:enable(false)
            formFields[FIELDKEY.CONSUMPTION_CORRECTION]:enable(false)
        end
    else  -- ENABLED
        formFields[FIELDKEY.HALF_DUPLEX]:enable(true)
        formFields[FIELDKEY.PIN_SWAP]:enable(true)
        if rfsuite.utils.apiVersionCompare(">=", "12.08") then
            formFields[FIELDKEY.VOLTAGE_CORRECTION]:enable(true)
            formFields[FIELDKEY.CURRENT_CORRECTION]:enable(true)
            formFields[FIELDKEY.CONSUMPTION_CORRECTION]:enable(true)
        end
    end

        
end


return {apidata = apidata, reboot = true, eepromWrite = true, title = title, event = event, wakeup = wakeup, postLoad = postLoad, onNavMenu = onNavMenu}
