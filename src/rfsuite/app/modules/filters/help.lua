--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local data = {}

data['help'] = {}

data['help']['default'] = {"Typically you would not edit this page without checking your Blackbox logs!", "Gyro lowpass: Lowpass filters for the gyro signal. Typically left at default.", "Gyro notch filters: Use for filtering specific frequency ranges. Typically not needed in most helis.", "Dynamic Notch Filters: Automatically creates notch filters within the min and max frequency range."}

data['fields'] = {}

return data
