--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local LOG_FIELDS_START = 1

local OFF_ON_OPTIONS = {"Off", "On"}

local apidata = {
    api = {
        [1] = "BLACKBOX_CONFIG"
    },
    formdata = {
        labels = {},
        fields = {
            {t = "Log Command", mspapi = 1, apikey = "fields->command", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Setpoint", mspapi = 1, apikey = "fields->setpoint", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Mixer", mspapi = 1, apikey = "fields->mixer", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log PID", mspapi = 1, apikey = "fields->pid", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Attitude", mspapi = 1, apikey = "fields->attitude", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Gyro Raw", mspapi = 1, apikey = "fields->gyroraw", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Gyro", mspapi = 1, apikey = "fields->gyro", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Acc", mspapi = 1, apikey = "fields->acc", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Mag", mspapi = 1, apikey = "fields->mag", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Alt", mspapi = 1, apikey = "fields->alt", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Battery", mspapi = 1, apikey = "fields->battery", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log RSSI", mspapi = 1, apikey = "fields->rssi", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log GPS", mspapi = 1, apikey = "fields->gps", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log RPM", mspapi = 1, apikey = "fields->rpm", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Motors", mspapi = 1, apikey = "fields->motors", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Servos", mspapi = 1, apikey = "fields->servos", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log VBEC", mspapi = 1, apikey = "fields->vbec", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log VBUS", mspapi = 1, apikey = "fields->vbus", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log Temps", mspapi = 1, apikey = "fields->temps", type = 1, table = OFF_ON_OPTIONS},
            {t = "Log ESC", mspapi = 1, apikey = "fields->esc", type = 1, table = OFF_ON_OPTIONS, apiversiongte = 12.07},
            {t = "Log BEC", mspapi = 1, apikey = "fields->bec", type = 1, table = OFF_ON_OPTIONS, apiversiongte = 12.07},
            {t = "Log ESC2", mspapi = 1, apikey = "fields->esc2", type = 1, table = OFF_ON_OPTIONS, apiversiongte = 12.07},
            {t = "Log Governor", mspapi = 1, apikey = "fields->governor", type = 1, table = OFF_ON_OPTIONS, apiversiongte = 12.09}
        }
    }
}

local function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function wakeup()
    local values = rfsuite.tasks.msp.api.apidata.values
    local cfg = values and values.BLACKBOX_CONFIG
    if not cfg and rfsuite.session and rfsuite.session.blackbox then
        cfg = rfsuite.session.blackbox.config
    end
    local blackboxSupported = cfg and tonumber(cfg.blackbox_supported or 0) == 1
    local device = cfg and tonumber(cfg.device or 0) or 0
    local mode = cfg and tonumber(cfg.mode or 0) or 0

    local enabled = blackboxSupported and device ~= 0 and mode ~= 0

    if rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields.save and rfsuite.app.formNavigationFields.save.enable then
        rfsuite.app.formNavigationFields.save:enable(enabled)
    end

    for i = LOG_FIELDS_START, #apidata.formdata.fields do
        local f = apidata.formdata.fields[i]
        local widget = rfsuite.app.formFields[i]
        if widget and widget.enable and f then
            local valid = (f.apiversion == nil or rfsuite.utils.apiVersionCompare(">=", f.apiversion))
                and (f.apiversionlt == nil or rfsuite.utils.apiVersionCompare("<", f.apiversionlt))
                and (f.apiversiongt == nil or rfsuite.utils.apiVersionCompare(">", f.apiversiongt))
                and (f.apiversionlte == nil or rfsuite.utils.apiVersionCompare("<=", f.apiversionlte))
                and (f.apiversiongte == nil or rfsuite.utils.apiVersionCompare(">=", f.apiversiongte))
            widget:enable(enabled and valid)
        end
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
