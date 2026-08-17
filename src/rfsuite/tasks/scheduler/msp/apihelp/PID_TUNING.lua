--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["pid_0_P"] = "How tightly the system tracks the desired setpoint.",
    ["pid_0_I"] = "How tightly the system holds its position.",
    ["pid_0_D"] = "Strength of dampening to any motion on the system, including external influences. Also reduces overshoot.",
    ["pid_0_F"] = "Helps push P-term based on stick input. Increasing will make response more sharp, but can cause overshoot.",
    ["pid_1_P"] = "How tightly the system tracks the desired setpoint.",
    ["pid_1_I"] = "How tightly the system holds its position.",
    ["pid_1_D"] = "Strength of dampening to any motion on the system, including external influences. Also reduces overshoot.",
    ["pid_1_F"] = "Helps push P-term based on stick input. Increasing will make response more sharp, but can cause overshoot.",
    ["pid_2_P"] = "How tightly the system tracks the desired setpoint.",
    ["pid_2_I"] = "How tightly the system holds its position.",
    ["pid_2_D"] = "Strength of dampening to any motion on the system, including external influences. Also reduces overshoot.",
    ["pid_2_F"] = "Helps push P-term based on stick input. Increasing will make response more sharp, but can cause overshoot.",
    ["pid_0_B"] = "Additional boost on the feedforward to make the heli react more to quick stick movements.",
    ["pid_1_B"] = "Additional boost on the feedforward to make the heli react more to quick stick movements.",
    ["pid_2_B"] = "Additional boost on the feedforward to make the heli react more to quick stick movements.",
    ["pid_0_O"] = "Used to prevent the craft from rolling when using high collective.",
    ["pid_1_O"] = "Used to prevent the craft from pitching when using high collective.",
}
