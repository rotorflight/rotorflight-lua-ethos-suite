--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
Sensor metadata table.
Purpose:
- Keep user-facing sensor metadata separate from transport source candidates.
- Keep telemetry source files transport-focused and easier to maintain.

Update process:
1. Add or update sensor keys here first.
2. Mirror every key in `sim.lua`, `sport.lua`, `crsf.lua`, and `crsf_legacy.lua`.
3. Keep this file metadata-only (no transport source candidate lists).
]]

local rfsuite = require("rfsuite")

local t_insert = table.insert
local t_pairs = pairs
local t_ipairs = ipairs
local t_type = type

local function convertThresholds(thrs, conv)
    if not thrs then return nil end
    local result = {}
    for i, t in t_ipairs(thrs) do
        local copy = {}
        for k, v in t_pairs(t) do copy[k] = v end
        if t_type(copy.value) == "number" then copy.value = conv(copy.value) end
        t_insert(result, copy)
    end
    return result
end

return {

    rssi = {
        name = "@i18n(sensors.rssi)@",
        mandatory = true,
        stats = true,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    link = {
        name = "@i18n(sensors.link)@",
        mandatory = true,
        stats = true,
        switch_alerts = true,
        unit = UNIT_DB,
        unit_string = "dB",
    },

    vfr = {
        name = "@i18n(sensors.vfr)@",
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    armflags = {
        name = "@i18n(sensors.arming_flags)@",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 90,
        onchange = function(value) rfsuite.session.isArmed = (value == 1 or value == 3) end
    },

    voltage = {
        name = "@i18n(sensors.voltage)@",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 3,
        switch_alerts = true,
        unit = UNIT_VOLT,
        unit_string = "V",
    },

    rpm = {
        name = "@i18n(sensors.headspeed)@",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 60,
        switch_alerts = true,
        unit = UNIT_RPM,
        unit_string = "rpm",
    },

    current = {
        name = "@i18n(sensors.current)@",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 4,
        switch_alerts = true,
        unit = UNIT_AMPERE,
        unit_string = "A",
    },

    temp_esc = {
        name = "@i18n(sensors.esc_temp)@",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 23,
        switch_alerts = true,
        unit = UNIT_DEGREE,
        localizations = function(value, paramMin, paramMax, paramThresholds)
            if value == nil then return nil, UNIT_DEGREE, nil, paramMin, paramMax, paramThresholds end

            local min = paramMin or 0
            local max = paramMax or 100
            local thresholds = paramThresholds

            local prefs = rfsuite.preferences.localizations
            local isFahrenheit = prefs and prefs.temperature_unit == 1


            if isFahrenheit then
                return value * 1.8 + 32, UNIT_DEGREE, "°F", min * 1.8 + 32, max * 1.8 + 32, convertThresholds(thresholds, function(v) return v * 1.8 + 32 end)
            end
            return value, UNIT_DEGREE, "°C", min, max, thresholds
        end
    },

    temp_mcu = {
        name = "@i18n(sensors.mcu_temp)@",
        mandatory = false,
        stats = true,
        set_telemetry_sensors = 52,
        switch_alerts = true,
        unit = UNIT_DEGREE,
        localizations = function(value, paramMin, paramMax, paramThresholds)
            if value == nil then return nil, UNIT_DEGREE, nil, paramMin, paramMax, paramThresholds end
            local min = paramMin or 0
            local max = paramMax or 100
            local thresholds = paramThresholds
            local prefs = rfsuite.preferences.localizations
            local isFahrenheit = prefs and prefs.temperature_unit == 1


            if isFahrenheit then
                return value * 1.8 + 32, UNIT_DEGREE, "°F", min * 1.8 + 32, max * 1.8 + 32, convertThresholds(thresholds, function(v) return v * 1.8 + 32 end)
            end
            return value, UNIT_DEGREE, "°C", min, max, thresholds
        end
    },

    fuel = {
        name = "@i18n(sensors.fuel)@",
        mandatory = false,
        stats = true,
        set_telemetry_sensors = 6,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    smartfuel = {
        name = "@i18n(sensors.smartfuel)@",
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    smartconsumption = {
        name = "@i18n(sensors.smartconsumption)@",
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_MILLIAMPERE_HOUR,
        unit_string = "mAh",
    },

    consumption = {
        name = "@i18n(sensors.consumption)@",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 5,
        switch_alerts = true,
        unit = UNIT_MILLIAMPERE_HOUR,
        unit_string = "mAh",
    },

    governor = {
        name = "@i18n(sensors.governor)@",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 93,
    },

    adj_f = {
        name = "@i18n(sensors.adj_func)@",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 99,
    },

    adj_v = {
        name = "@i18n(sensors.adj_val)@",
        mandatory = true,
        stats = false,
    },

    pid_profile = {
        name = "@i18n(sensors.pid_profile)@",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 95,
    },

    rate_profile = {
        name = "@i18n(sensors.rate_profile)@",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 96,
    },

    throttle_percent = {
        name = "@i18n(sensors.throttle_pct)@",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 15,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    armdisableflags = {
        name = "@i18n(sensors.armdisableflags)@",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 91,
    },

    altitude = {
        name = "@i18n(sensors.altitude)@",
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_METER,
        localizations = function(value)
            local major = UNIT_METER
            if value == nil then return nil, major, nil end
            local prefs = rfsuite.preferences.localizations
            local isFeet = prefs and prefs.altitude_unit == 1
            if isFeet then return value * 3.28084, major, "ft" end
            return value, major, "m"
        end
    },

    bec_voltage = {
        name              = "@i18n(sensors.bec_voltage)@",
        mandatory         = true,
        stats             = true,
        set_telemetry_sensors = 43,
        switch_alerts     = true,
        unit              = UNIT_VOLT,
        unit_string       = "V",
    },

    cell_count = {
        name = "@i18n(sensors.cell_count)@",
        mandatory = false,
        stats = false,
    },

    accx = {
        name = "@i18n(sensors.accx)@",
        mandatory = false,
        stats = false,
    },

    accy = {
        name = "@i18n(sensors.accy)@",
        mandatory = false,
        stats = false,
    },

    accz = {
        name = "@i18n(sensors.accz)@",
        mandatory = false,
        stats = false,
    },

    attyaw = {
        name = "@i18n(sensors.attyaw)@",
        mandatory = false,
        stats = false,
    },

    attroll = {
        name = "@i18n(sensors.attroll)@",
        mandatory = false,
        stats = false,
    },

    attpitch = {
        name = "@i18n(sensors.attpitch)@",
        mandatory = false,
        stats = false,
    },

    groundspeed = {
        name = "@i18n(sensors.groundspeed)@",
        mandatory = false,
        stats = false,
    },
}
