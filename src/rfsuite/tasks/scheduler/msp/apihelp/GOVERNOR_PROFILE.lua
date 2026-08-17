--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["governor_flags->fallback_precomp"] = "@i18n(api.GOVERNOR_PROFILE.fallback_precomp)@",
    ["governor_flags->voltage_comp"] = "@i18n(api.GOVERNOR_PROFILE.voltage_comp)@",
    ["governor_flags->pid_spoolup"] = "@i18n(api.GOVERNOR_PROFILE.pid_spoolup)@",
    ["governor_flags->dyn_min_throttle"] = "@i18n(api.GOVERNOR_PROFILE.dyn_min_throttle)@",
    ["governor_headspeed"] = "Target headspeed for the current profile.",
    ["governor_gain"] = "Master PID loop gain.",
    ["governor_p_gain"] = "PID loop P-term gain.",
    ["governor_i_gain"] = "PID loop I-term gain.",
    ["governor_d_gain"] = "PID loop D-term gain.",
    ["governor_f_gain"] = "Feedforward gain.",
    ["governor_tta_gain"] = "TTA gain applied to increase headspeed to control the tail in the negative direction (e.g. motorised tail less than idle speed).",
    ["governor_tta_limit"] = "TTA max headspeed increase over full headspeed.",
    ["governor_yaw_weight"] = "@i18n(api.GOVERNOR_PROFILE.governor_yaw_weight)@",
    ["governor_cyclic_weight"] = "@i18n(api.GOVERNOR_PROFILE.governor_cyclic_weight)@",
    ["governor_collective_weight"] = "@i18n(api.GOVERNOR_PROFILE.governor_collective_weight)@",
    ["governor_max_throttle"] = "Maximum output throttle the governor is allowed to use.",
    ["governor_min_throttle"] = "Minimum output throttle the governor is allowed to use.",
    ["governor_fallback_drop"] = "@i18n(api.GOVERNOR_PROFILE.governor_fallback_drop)@",
    ["governor_flags"] = "@i18n(api.GOVERNOR_PROFILE.governor_flags)@",
    ["governor_yaw_ff_weight"] = "Yaw precompensation weight - how much yaw is mixed into the feedforward.",
    ["governor_cyclic_ff_weight"] = "Cyclic precompensation weight - how much cyclic is mixed into the feedforward.",
    ["governor_collective_ff_weight"] = "Collective precompensation weight - how much collective is mixed into the feedforward.",
}
