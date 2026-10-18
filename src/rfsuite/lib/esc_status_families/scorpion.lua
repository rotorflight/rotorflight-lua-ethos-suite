-- Scorpion telemetry (signature 0x53, firmware ESC_SIG_TRIB), "Error Code bits" (the protocol
-- comment above the Scorpion decoder). Bits 0 and 6 are not assigned. Levels: 3 ERROR.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local T = requireModule("lib/esc_status_text.lua")
local ERR = 3
return {
  name = "Scorpion",
  highest = 7,
  bits = {
    [1] = {T.bec_voltage, ERR},
    [2] = {T.overheat, ERR},
    [3] = {T.consumption, ERR},
    [4] = {T.input_voltage, ERR},
    [5] = {T.overcurrent, ERR},
    [7] = {T.throttle, ERR},
  },
}
