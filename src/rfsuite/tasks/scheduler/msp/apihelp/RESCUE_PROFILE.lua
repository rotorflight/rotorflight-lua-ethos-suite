--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["rescue_mode"] = "@i18n(api.RESCUE_PROFILE.help_rescue_mode)@",
    ["rescue_flip_mode"] = "If rescue is activated while inverted, flip to upright - or remain inverted.",
    ["rescue_flip_gain"] = "Determine how aggressively the heli flips during inverted rescue.",
    ["rescue_level_gain"] = "Determine how aggressively the heli levels during rescue.",
    ["rescue_pull_up_time"] = "When rescue is activated, helicopter will apply pull-up collective for this time period before moving to flip or climb stage.",
    ["rescue_climb_time"] = "Length of time the climb collective is applied before switching to hover.",
    ["rescue_flip_time"] = "If the helicopter is in rescue and is trying to flip to upright and does not within this time, rescue will be aborted.",
    ["rescue_exit_time"] = "This limits rapid application of negative collective if the helicopter has rolled during rescue.",
    ["rescue_pull_up_collective"] = "Collective value for pull-up climb.",
    ["rescue_climb_collective"] = "Collective value for rescue climb.",
    ["rescue_hover_collective"] = "Collective value for hover.",
    ["rescue_hover_altitude"] = "@i18n(api.RESCUE_PROFILE.help_rescue_hover_altitude)@",
    ["rescue_alt_p_gain"] = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_p_gain)@",
    ["rescue_alt_i_gain"] = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_i_gain)@",
    ["rescue_alt_d_gain"] = "@i18n(api.RESCUE_PROFILE.help_rescue_alt_d_gain)@",
    ["rescue_max_collective"] = "@i18n(api.RESCUE_PROFILE.help_rescue_max_collective)@",
    ["rescue_max_setpoint_rate"] = "Limit rescue roll/pitch rate. Larger helicopters may need slower rotation rates.",
    ["rescue_max_setpoint_accel"] = "Limit how fast the helicopter accelerates into a roll/pitch. Larger helicopters may need slower acceleration.",
}
