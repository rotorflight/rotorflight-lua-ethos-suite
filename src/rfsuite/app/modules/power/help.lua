--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local data = {}

data['help'] = {}

data['help']['default'] = {"@i18n(app.modules.power.help_p1)@"}

data['fields'] = {
    ["smartfuel_remote_source"] = {t = "@i18n(sensors.smartfuel)@"},
    ["smartfuel_mode"]          = {t = "@i18n(api.SMARTFUEL_CONFIG.smartfuel_mode)@"},
    ["voltage_drop_rate"]       = {t = "@i18n(api.SMARTFUEL_CONFIG.voltage_drop_rate)@"},
    ["charge_drop_rate"]        = {t = "@i18n(api.SMARTFUEL_CONFIG.charge_drop_rate)@"},
    ["sag_gain"]                = {t = "@i18n(api.SMARTFUEL_CONFIG.sag_gain)@"},
    ["smartfuel_model_type"]    = {t = "@i18n(app.modules.power.model_type)@"},
    ["smartfuel_source"]        = {t = "@i18n(api.BATTERY_INI.smartfuel_source)@"},
    ["alert_type"]              = {t = "@i18n(api.BATTERY_INI.alert_type)@"},
    ["becalertvalue"]           = {t = "@i18n(api.BATTERY_INI.becalertvalue)@"},
    ["rxalertvalue"]            = {t = "@i18n(api.BATTERY_INI.rxalertvalue)@"},
    ["flighttime"]              = {t = "@i18n(api.BATTERY_INI.flighttime)@"},
}

return data
