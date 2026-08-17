--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["gov_mode"] = "@i18n(api.GOVERNOR_CONFIG.gov_mode)@",
    ["gov_startup_time"] = "Time constant for slow startup, in seconds, measuring the time from zero to full headspeed.",
    ["gov_spoolup_time"] = "Time constant for slow spoolup, in seconds, measuring the time from zero to full headspeed.",
    ["gov_tracking_time"] = "Time constant for headspeed changes, in seconds, measuring the time from zero to full headspeed.",
    ["gov_recovery_time"] = "Time constant for recovery spoolup, in seconds, measuring the time from zero to full headspeed.",
    ["gov_throttle_hold_timeout"] = "@i18n(api.GOVERNOR_CONFIG.gov_throttle_hold_timeout)@",
    ["gov_autorotation_timeout"] = "@i18n(api.GOVERNOR_CONFIG.gov_autorotation_timeout)@",
    ["gov_handover_throttle"] = "Governor activates above this %. Below this the input throttle is passed to the ESC.",
    ["gov_pwr_filter"] = "@i18n(api.GOVERNOR_CONFIG.gov_pwr_filter)@",
    ["gov_rpm_filter"] = "@i18n(api.GOVERNOR_CONFIG.gov_rpm_filter)@",
    ["gov_tta_filter"] = "@i18n(api.GOVERNOR_CONFIG.gov_tta_filter)@",
    ["gov_ff_filter"] = "@i18n(api.GOVERNOR_CONFIG.gov_ff_filter)@",
    ["gov_d_filter"] = "@i18n(api.GOVERNOR_CONFIG.gov_d_filter)@",
    ["gov_spooldown_time"] = "@i18n(api.GOVERNOR_CONFIG.gov_spooldown_time)@",
    ["gov_throttle_type"] = "@i18n(api.GOVERNOR_CONFIG.gov_throttle_type)@",
    ["governor_idle_throttle"] = "Idle throttle",
    ["governor_auto_throttle"] = "Auto throttle",
    ["gov_zero_throttle_timeout"] = "@i18n(api.GOVERNOR_CONFIG.gov_zero_throttle_timeout)@",
    ["gov_lost_headspeed_timeout"] = "@i18n(api.GOVERNOR_CONFIG.gov_lost_headspeed_timeout)@",
    ["gov_autorotation_bailout_time"] = "@i18n(api.GOVERNOR_CONFIG.gov_autorotation_bailout_time)@",
    ["gov_autorotation_min_entry_time"] = "@i18n(api.GOVERNOR_CONFIG.gov_autorotation_min_entry_time)@",
    ["gov_spoolup_min_throttle"] = "Minimum throttle to use for slow spoolup, in percent. For electric motors the default is 5%, for nitro this should be set so the clutch starts to engage for a smooth spoolup 10-15%.",
}
