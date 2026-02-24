--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
FrSky SPORT transport source candidates.
Each key maps to an ordered list of source descriptors tried left-to-right.

Update process:
1. Keys must stay in sync with `sensor_table.lua`.
2. Keep this file transport-only (no display metadata).
3. Use `nil` or `{nil}` when a sensor is not available in this transport.
]]

return {
    rssi = {{appId = 0xF010, subId = 0}},
    link = {{appId = 0xF101, subId = 0}, "RSSI"},
    vfr = {{appId = 0xF010, subId = 0}},
    armflags = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5122}, {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5462}},
    voltage = {
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0210},
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0211},
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0218},
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x021A}
            },
    rpm = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0500}},
    current = {
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200},
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0208},
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201}
            },
    temp_esc = {
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401, mspgt = {12, 0, 8}},
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0418}
            },
    temp_mcu = {
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0400, mspgt = {12, 0, 8}},
                {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0401, msplt = {12, 0, 7}}
            },
    fuel = {
                { category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600 }
            },
    smartfuel = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE1}},
    smartconsumption = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5FE0}},
    consumption = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250}},
    governor = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5125}, {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5450}},
    adj_f = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5110}},
    adj_v = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5111}},
    pid_profile = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5130}, {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5471}},
    rate_profile = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5131}, {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5472}},
    throttle_percent = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5440}, {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x51A4}, {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5269}},
    armdisableflags = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5123}},
    altitude = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0100}},
    bec_voltage = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0901}, {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0219}},
    cell_count = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5260}},
    accx = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0700}},
    accy = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0710}},
    accz = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0720}},
    attyaw = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5210}},
    attroll = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730, subId = 0}},
    attpitch = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0730, subId = 1}},
    groundspeed = {{category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0830, subId = 1}},
}
