--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local data = {}

data['help'] = {}

data['help']['default'] = {"The battery settings are used to configure the flight controller to monitor the battery voltage and provide warnings when the voltage drops below a certain level."}

data['fields'] = {
    ["smartfuel_remote_source"] = {t = "Smart Fuel"},
    ["smartfuel_mode"]          = {t = "Choose whether firmware SmartFuel is disabled, voltage-estimated, current consumption based, or combined. Combined uses the more pessimistic of voltage and current consumption."},
    ["voltage_drop_rate"]       = {t = "Limits how fast the measured per-cell voltage can fall (mV/s). Only applies in Voltage and Combined modes. Lower values produce a smoother but slower-responding estimate; higher values allow faster tracking."},
    ["charge_drop_rate"]        = {t = "Limits how fast the fuel percentage can drop per second on the voltage track. Only applies in Voltage and Combined modes once the model has been armed. Lower values give a more stable gauge during aggressive flying; higher values allow faster discharge tracking."},
    ["sag_gain"]                = {t = "Compensates for voltage sag under collective and cyclic load while airborne. Only applies in Voltage and Combined modes. Higher values apply more compensation; set to 0 to disable."},
    ["smartfuel_model_type"]    = {t = "Power Type"},
    ["smartfuel_source"]        = {t = "Choose whether local SmartFuel uses current consumption, pack voltage, or combined mode. Combined uses the more pessimistic of voltage and current consumption."},
    ["alert_type"]              = {t = "@i18n(api.BATTERY_INI.alert_type)@"},
    ["becalertvalue"]           = {t = "@i18n(api.BATTERY_INI.becalertvalue)@"},
    ["rxalertvalue"]            = {t = "@i18n(api.BATTERY_INI.rxalertvalue)@"},
    ["flighttime"]              = {t = "@i18n(api.BATTERY_INI.flighttime)@"},
}

return data
