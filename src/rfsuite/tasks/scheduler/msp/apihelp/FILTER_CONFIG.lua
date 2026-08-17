--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    ["gyro_hardware_lpf"] = "@i18n(api.FILTER_CONFIG.gyro_hardware_lpf)@",
    ["gyro_lpf1_type"] = "@i18n(api.FILTER_CONFIG.gyro_lpf1_type)@",
    ["gyro_lpf1_static_hz"] = "Lowpass filter cutoff frequency in Hz.",
    ["gyro_lpf2_type"] = "@i18n(api.FILTER_CONFIG.gyro_lpf2_type)@",
    ["gyro_lpf2_static_hz"] = "Lowpass filter cutoff frequency in Hz.",
    ["gyro_soft_notch_hz_1"] = "Center frequency to which the notch is applied.",
    ["gyro_soft_notch_cutoff_1"] = "Width of the notch filter in Hz.",
    ["gyro_soft_notch_hz_2"] = "Center frequency to which the notch is applied.",
    ["gyro_soft_notch_cutoff_2"] = "Width of the notch filter in Hz.",
    ["gyro_lpf1_dyn_min_hz"] = "Dynamic filter min cutoff in Hz.",
    ["gyro_lpf1_dyn_max_hz"] = "Dynamic filter max cutoff in Hz.",
    ["dyn_notch_count"] = "Number of notches to apply.",
    ["dyn_notch_q"] = "Quality factor of the notch filter.",
    ["dyn_notch_min_hz"] = "Minimum frequency to which the notch is applied.",
    ["dyn_notch_max_hz"] = "Maximum frequency to which the notch is applied.",
    ["rpm_preset"] = "@i18n(api.FILTER_CONFIG.rpm_preset)@",
    ["rpm_min_hz"] = "Minimum frequency for the RPM filter.",
}
