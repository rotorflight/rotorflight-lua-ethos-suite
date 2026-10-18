-- Hobbywing V5 (signature 0xFD, firmware ESC_SIG_PL5), "Fault code bits" (the protocol comment
-- above the PL5 frame decoder). Every bit is a fault the controller has acted on. Levels: 3 ERROR.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local T = requireModule("lib/esc_status_text.lua")
local ERR = 3
return {
  name = "Hobbywing V5",
  highest = 7,
  bits = {
    [0] = {T.motor_locked, ERR},
    [1] = {T.overheat, ERR},
    [2] = {T.throttle_at_start, ERR},
    [3] = {T.throttle_lost, ERR},
    [4] = {T.overcurrent, ERR},
    [5] = {T.undervoltage, ERR},
    [6] = {T.input_voltage, ERR},
    [7] = {T.motor_wiring, ERR},
  },
}
