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
    gyroLowpassFilterCutoff = {t = "Lowpass filter cutoff frequency in Hz."},
    gyroLowpassFilterDynamicCutoff = {t = "Dynamic filter min/max cutoff in Hz."},
    gyroLowpassFilterCenter = {t = "Center frequency to which the notch is applied."},
    gyroDynamicNotchCount = {t = "Without RPM filters, 4-6 is recommended. With the RPM filters, 2-4 is recommended."},
    gyroDynamicNotchQ = {t = "Values between 2 and 4 recommended. Lower than 2 will increase filter delay and may degrade flight performance."},
    gyroDynamicNotchMinHz = {t = "Lowest incoming noise frequency to be filtered. Should be slightly below lowest main rotor fundamental, but no less than 20Hz."},
    gyroDynamicNotchMaxHz = {t = "Highest incoming noise frequency to be filtered. Should be 10-20% above highest tail rotor fundamental."}
}

return data
