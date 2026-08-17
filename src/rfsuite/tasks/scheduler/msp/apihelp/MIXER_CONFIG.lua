--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["main_rotor_dir"] = "@i18n(api.MIXER_CONFIG.main_rotor_dir)@",
    ["tail_rotor_mode"] = "@i18n(api.MIXER_CONFIG.tail_rotor_mode)@",
    ["tail_motor_idle"] = "Minimum throttle signal sent to the tail motor. This should be set just high enough that the motor does not stop.",
    ["tail_center_trim"] = "Sets tail rotor trim for 0 yaw for variable pitch, or tail motor throttle for 0 yaw for motorized.",
    ["swash_type"] = "@i18n(api.MIXER_CONFIG.swash_type)@",
    ["swash_ring"] = "@i18n(api.MIXER_CONFIG.swash_ring)@",
    ["swash_phase"] = "Phase offset for the swashplate controls.",
    ["swash_pitch_limit"] = "Maximum amount of combined cyclic and collective blade pitch.",
    ["swash_trim_0"] = "Swash trim to level the swash plate when using fixed links.",
    ["swash_trim_1"] = "Swash trim to level the swash plate when using fixed links.",
    ["swash_trim_2"] = "Swash trim to level the swash plate when using fixed links.",
    ["swash_tta_precomp"] = "Mixer precomp for 0 yaw.",
    ["swash_geo_correction"] = "Adjust if there is too much negative collective or too much positive collective.",
    ["collective_tilt_correction_pos"] = "Adjust the collective tilt correction scaling for positive collective pitch.",
    ["collective_tilt_correction_neg"] = "Adjust the collective tilt correction scaling for negative collective pitch.",
}
