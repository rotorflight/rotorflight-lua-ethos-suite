-- Graupner telemetry (signature 0xC0), "Warning flags" (the protocol comment above the Graupner
-- decoder). The protocol pairs the whole field with a warning tone, so no bit is raised to an
-- error here. Levels: 2 WARNING.
local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local T = requireModule("lib/esc_status_text.lua")
local WRN = 2
return {
  name = "Graupner",
  highest = 6,
  bits = {
    [0] = {T.undervoltage, WRN},
    [1] = {T.temp_warning, WRN},
    [2] = {T.motor_hot, WRN},
    [3] = {T.current_limit, WRN},
    [4] = {T.rpm_low, WRN},
    [5] = {T.capacity_limit, WRN},
    [6] = {T.current_limit, WRN},
  },
}
