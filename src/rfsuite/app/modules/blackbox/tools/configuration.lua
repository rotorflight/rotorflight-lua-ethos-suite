--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local FIELD = {
    DEVICE = 1,
    MODE = 2,
    DENOM = 3,
    INITIAL_ERASE_KIB = 4,
    ROLLING_ERASE = 5,
    GRACE_PERIOD = 6
}

local apidata = {
    api = {
        [1] = "BLACKBOX_CONFIG"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "Device", mspapi = 1, apikey = "device", type = 1, table = {"Disabled", "Onboard Flash", "SD Card", "Serial Port"}},
            {t = "Mode", mspapi = 1, apikey = "mode", type = 1, table = {"Off", "Normal", "Armed", "Switch"}},
            {t = "Rate Denominator", mspapi = 1, apikey = "denom", min = 1, max = 65535},
            {t = "Initial Erase Free (KiB)", mspapi = 1, apikey = "initialEraseFreeSpaceKiB", min = 0, max = 65535},
            {t = "Rolling Erase", mspapi = 1, apikey = "rollingErase", type = 1, table = {"Off", "On"}},
            {t = "Grace Period", mspapi = 1, apikey = "gracePeriod", min = 0, max = 255}
        }
    }
}

local function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function wakeup()
    local values = rfsuite.tasks.msp.api.apidata.values
    local cfg = values and values.BLACKBOX_CONFIG
    local blackboxSupported = cfg and tonumber(cfg.blackbox_supported or 0) == 1

    if rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields.save and rfsuite.app.formNavigationFields.save.enable then
        rfsuite.app.formNavigationFields.save:enable(blackboxSupported == true)
    end

    local device = tonumber(apidata.formdata.fields[FIELD.DEVICE].value or 0) or 0
    local mode = tonumber(apidata.formdata.fields[FIELD.MODE].value or 0) or 0

    if rfsuite.app.formFields[FIELD.INITIAL_ERASE_KIB] and rfsuite.app.formFields[FIELD.INITIAL_ERASE_KIB].enable then
        rfsuite.app.formFields[FIELD.INITIAL_ERASE_KIB]:enable(device == 1 and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end

    if rfsuite.app.formFields[FIELD.ROLLING_ERASE] and rfsuite.app.formFields[FIELD.ROLLING_ERASE].enable then
        rfsuite.app.formFields[FIELD.ROLLING_ERASE]:enable(device == 1 and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end

    if rfsuite.app.formFields[FIELD.GRACE_PERIOD] and rfsuite.app.formFields[FIELD.GRACE_PERIOD].enable then
        rfsuite.app.formFields[FIELD.GRACE_PERIOD]:enable(device ~= 0 and (mode == 1 or mode == 2) and rfsuite.utils.apiVersionCompare(">=", "12.08"))
    end
end

local function event(widget, category, value)
    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage({idx = rfsuite.app.lastIdx, title = "Blackbox", script = "blackbox/blackbox.lua"})
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.openPage({idx = rfsuite.app.lastIdx, title = "Blackbox", script = "blackbox/blackbox.lua"})
end

return {apidata = apidata, eepromWrite = true, reboot = false, postLoad = postLoad, wakeup = wakeup, event = event, onNavMenu = onNavMenu, API = {}, navButtons = {menu = true, save = true, reload = true, tool = false, help = true}}
