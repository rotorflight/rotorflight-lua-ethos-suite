--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
CRSF legacy fallback source candidates.
Values here are mostly legacy sensor names and may resolve differently by radio firmware.

Update process:
1. Keys must stay in sync with `sensor_table.lua`.
2. Keep this file transport-only (no display metadata).
3. Use `nil` or `{nil}` when a sensor is not available in legacy mode.
]]

return {
    rssi = {{crsfId = 0x14, subIdStart = 0, subIdEnd = 1}},
    link = {{crsfId = 0x14, subIdStart = 0, subIdEnd = 1}, "RSSI 1", "RSSI 2"},
    vfr = {{crsfId = 0x14, subIdStart = 0, subIdEnd = 1}},
    armflags = {nil},
    voltage = {"Rx Batt"},
    rpm = {"GPS Alt"},
    current = {"Rx Curr"},
    temp_esc = {"GPS Speed"},
    temp_mcu = {"GPS Sats"},
    fuel = { "Rx Batt%" },
    smartfuel = nil,
    smartconsumption = nil,
    consumption = {"Rx Cons"},
    governor = {"Flight mode"},
    adj_f = {nil},
    adj_v = {nil},
    pid_profile = {nil},
    rate_profile = {nil},
    throttle_percent = {nil},
    armdisableflags = {nil},
    altitude = {nil},
    bec_voltage = {nil},
    cell_count = {nil},
    accx = {nil},
    accy = {nil},
    accz = {nil},
    attyaw = {nil},
    attroll = {nil},
    attpitch = {nil},
    groundspeed = {nil},
}
