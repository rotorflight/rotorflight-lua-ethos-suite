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
        name = "RSSI",
        mandatory = true,
        stats = true,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    link = {
        name = "Link Quality",
        mandatory = true,
        stats = true,
        switch_alerts = true,
        unit = UNIT_DB,
        unit_string = "dB",
    },

    vfr = {
        name = "VFR",
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    armflags = {
        name = "Arming Flags",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 90,
        onchange = function(value)
            local armed = rfsuite.utils.armFlagsToIsArmed(value)
            if armed ~= nil then
                rfsuite.session.isArmed = armed
            end
        end
    },

    voltage = {
        name = "Voltage",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 3,
        switch_alerts = true,
        unit = UNIT_VOLT,
        unit_string = "V",
    },

    cell_voltage = {
        name = "Cell Voltage",
        mandatory = false,
        stats = true,
        set_telemetry_sensors = 8,
        switch_alerts = true,
        unit = UNIT_VOLT,
        unit_string = "V",
    },

    rpm = {
        name = "Headspeed",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 60,
        switch_alerts = true,
        unit = UNIT_RPM,
        unit_string = "rpm",
    },

    tailspeed = {
        name = "Tailspeed",
        mandatory = false,
        stats = true,
        set_telemetry_sensors = 61,
        switch_alerts = true,
        unit = UNIT_RPM,
        unit_string = "rpm",
    },

    current = {
        name = "Current",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 4,
        switch_alerts = true,
        unit = UNIT_AMPERE,
        unit_string = "A",
    },

    temp_esc = {
        name = "ESC Temperature",
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
        name = "MCU Temperature",
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
        name = "Fuel",
        mandatory = false,
        stats = true,
        set_telemetry_sensors = 6,
        default_telemetry_sensor = true,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    smartfuel = {
        name = "Smart Fuel",
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_PERCENT,
        unit_string = "%",
        transform = function(value)
            if value ~= nil and value < 0 then
                return nil
            end
            return value
        end,
    },

    smartconsumption = {
        name = "Smart Consumption",
        mandatory = false,
        stats = true,
        switch_alerts = true,
        unit = UNIT_MILLIAMPERE_HOUR,
        unit_string = "mAh",
    },

    consumption = {
        name = "Consumption",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 5,
        switch_alerts = true,
        unit = UNIT_MILLIAMPERE_HOUR,
        unit_string = "mAh",
    },

    governor = {
        name = "Governor State",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 93,
    },

    adj_f = {
        name = "Adj (Function)",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 99,
    },

    adj_v = {
        name = "Adj (Value)",
        mandatory = true,
        stats = false,
    },

    pid_profile = {
        name = "PID Profile",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 95,
    },

    rate_profile = {
        name = "Rate Profile",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 96,
    },

    throttle_percent = {
        name = "Throttle %",
        mandatory = true,
        stats = true,
        set_telemetry_sensors = 15,
        unit = UNIT_PERCENT,
        unit_string = "%",
    },

    armdisableflags = {
        name = "Arming Disable",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 91,
    },

    altitude = {
        name = "Altitude",
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
        name              = "Bec Voltage",
        mandatory         = true,
        stats             = true,
        set_telemetry_sensors = 43,
        switch_alerts     = true,
        unit              = UNIT_VOLT,
        unit_string       = "V",
    },

    cell_count = {
        name = "Cell count",
        mandatory = false,
        stats = false,
    },

    accx = {
        name = "Accel X",
        mandatory = false,
        stats = false,
    },

    accy = {
        name = "Accel Y",
        mandatory = false,
        stats = false,
    },

    accz = {
        name = "Accel Z",
        mandatory = false,
        stats = false,
    },

    attyaw = {
        name = "Y.angle",
        mandatory = false,
        stats = false,
    },

    attroll = {
        name = "R.angle",
        mandatory = false,
        stats = false,
    },

    attpitch = {
        name = "P.angle",
        mandatory = false,
        stats = false,
    },

    groundspeed = {
        name = "Ground Speed",
        mandatory = false,
        stats = false,
    },

    battery_profile = {
        name = "Battery Profile",
        mandatory = true,
        stats = false,
        set_telemetry_sensors = 97,
    },
}
