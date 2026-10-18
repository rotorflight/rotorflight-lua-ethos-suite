-- Advanced Power Drives UART telemetry, "Status flags" (firmware: src/main/sensors/esc_sensor.c,
-- the protocol comment above apdSensorProcess). Bit 0 is "motor started", a running motor and not
-- a fault, so it is masked out (ignore) rather than given a text. Levels: 1 OK, 2 WARNING, 3 ERROR.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local T = requireModule("lib/esc_status_text.lua")
local ERR, WRN = 3, 2
return {
  name = "APD",
  highest = 5,
  ignore = {[0] = true},
  bits = {
    [1] = {T.motor_saturated, WRN},
    [2] = {T.overheat, ERR},
    [3] = {T.overvoltage, ERR},
    [4] = {T.undervoltage, ERR},
    [5] = {T.startup, ERR},
  },
}
