--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["rc_center"] = "Stick center in microseconds (us).",
    ["rc_deflection"] = "Stick deflection from center in microseconds (us).",
    ["rc_arm_throttle"] = "Throttle must be at or below this value in microseconds (us) to allow arming. Must be at least 10us lower than minimum throttle.",
    ["rc_min_throttle"] = "Minimum throttle (0% throttle output) expected from radio, in microseconds (us).",
    ["rc_max_throttle"] = "Maximum throttle (100% throttle output) expected from radio, in microseconds (us).",
    ["rc_deadband"] = "Deadband for cyclic control in microseconds (us).",
    ["rc_yaw_deadband"] = "Deadband for yaw control in microseconds (us).",
}
