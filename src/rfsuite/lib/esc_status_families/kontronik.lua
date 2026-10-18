-- Kontronik Telemetry V4, "Error flags" (firmware: src/main/sensors/esc_sensor.c, the protocol
-- comment above kontronikSensorProcess). 24 bits. Bits 11 and 23 are the same condition in the
-- protocol's own list and share one text. Levels: 1 OK, 2 WARNING, 3 ERROR.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local T = requireModule("lib/esc_status_text.lua")
local ERR, WRN, INF = 3, 2, 1
return {
  name = "Kontronik",
  highest = 23,
  bits = {
    [0] = {T.undervoltage, ERR},
    [1] = {T.overvoltage, ERR},
    [2] = {T.overcurrent, ERR},
    [3] = {T.current_warning, WRN},
    [4] = {T.temp_warning, WRN},
    [5] = {T.overheat, ERR},
    [6] = {T.bec_undervoltage, ERR},
    [7] = {T.bec_overvoltage, ERR},
    [8] = {T.bec_overcurrent, ERR},
    [9] = {T.bec_overheat, ERR},
    [10] = {T.rudder_cutoff, WRN},
    [11] = {T.capacity_limit, WRN},
    [12] = {T.operation, ERR},
    [13] = {T.operation_warning, WRN},
    [14] = {T.self_test, ERR},
    [15] = {T.eeprom, ERR},
    [16] = {T.watchdog, ERR},
    -- "Programming is still permitted" reports what the controller will accept, not a fault.
    [17] = {T.programming_open, INF},
    [18] = {T.battery_limit, WRN},
    [19] = {T.current_limit, WRN},
    [20] = {T.esc_temp_limit, WRN},
    [21] = {T.bec_temp_limit, WRN},
    [22] = {T.current_limit, WRN},
    [23] = {T.capacity_limit, WRN},
  },
}
