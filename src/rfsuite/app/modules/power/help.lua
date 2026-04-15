--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local data = {}

data['help'] = {}

data['help']['default'] = {"@i18n(app.modules.power.help_p1)@"}

data['fields'] = {
    ["smartfuel_remote_source"] = {t = "@i18n(sensors.smartfuel)@"},
    ["smartfuel_model_type"] = {t = "@i18n(app.modules.power.model_type)@"},
    ["smartfuel_source"] = {t = "@i18n(api.BATTERY_INI.smartfuel_source)@"},
    ["stabilize_delay"] = {t = "@i18n(api.BATTERY_INI.stabilize_delay)@"},
    ["stable_window"] = {t = "@i18n(api.BATTERY_INI.stable_window)@"},
    ["voltage_fall_limit"] = {t = "@i18n(api.BATTERY_INI.voltage_fall_limit)@"},
    ["fuel_drop_rate"] = {t = "@i18n(api.BATTERY_INI.fuel_drop_rate)@"},
    ["sag_multiplier_percent"] = {t = "@i18n(api.BATTERY_INI.sag_multiplier_percent)@"},
    ["alert_type"] = {t = "@i18n(api.BATTERY_INI.alert_type)@"},
    ["becalertvalue"] = {t = "@i18n(api.BATTERY_INI.becalertvalue)@"},
    ["rxalertvalue"] = {t = "@i18n(api.BATTERY_INI.rxalertvalue)@"},
    ["flighttime"] = {t = "@i18n(api.BATTERY_INI.flighttime)@"},
}

return data
