--[[
 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local data = {}

data['help'] = {}

data['help']['default'] = {"Typically you would not edit this page without checking your Blackbox logs!", "Gyro lowpass: Lowpass filters for the gyro signal. Typically left at default.", "Gyro notch filters: Use for filtering specific frequency ranges. Typically not needed in most helis.", "Dynamic Notch Filters: Automatically creates notch filters within the min and max frequency range."}

data['fields'] = {
    gyro_lpf1_static_hz = {t = "Lowpass filter cutoff frequency in Hz."},
    gyro_lpf1_dyn_min_hz = {t = "Dynamic filter min/max cutoff in Hz."},
    gyro_lpf1_dyn_max_hz = {t = "Dynamic filter min/max cutoff in Hz."},
    gyro_lpf2_static_hz = {t = "Lowpass filter cutoff frequency in Hz."},
    gyro_soft_notch_hz_1 = {t = "Center frequency to which the notch is applied."},
    gyro_soft_notch_cutoff_1 = {t = "Width of the notch filter in Hz."},
    gyro_soft_notch_hz_2 = {t = "Center frequency to which the notch is applied."},
    gyro_soft_notch_cutoff_2 = {t = "Width of the notch filter in Hz."},
}

return data
