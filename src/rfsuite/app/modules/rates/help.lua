--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local data = {}

data['help'] = {}

data['help']['default'] = {"Default: We keep this to make button appear for rates.", "We will use the sub keys below."}

data["help"]["table"] = {}

data["help"]["table"][0] = {"All values are set to zero because no RATE TABLE is in use."}

data["help"]["table"][1] = {"RC Rate: Maximum rotation rate at full stick deflection.", "SuperRate: Increases maximum rotation rate while reducing sensitivity around half stick.", "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

data["help"]["table"][2] = {"Rate: Maximum rotation rate at full stick deflection in degrees per second.", "Acro+: Increases the maximum rotation rate while reducing sensitivity around half stick.", "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

data["help"]["table"][3] = {"RC Rate: Maximum rotation rate at full stick deflection.", "Rate: Increases maximum rotation rate while reducing sensitivity around half stick.", "RC Curve: Reduces sensitivity near the stick's center where fine controls are needed."}

data["help"]["table"][4] = {"Center Sensitivity: Use to reduce sensitivity around center stick. Set Center Sensitivity to the same as Max Rate for a linear response. A lower number than Max Rate will reduce sensitivity around center stick. Note that higher than Max Rate will increase the Max Rate - not recommended as it causes issues in the Blackbox log.", "Max Rate: Maximum rotation rate at full stick deflection in degrees per second.", "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

data["help"]["table"][5] = {"RC Rate: Use to reduce sensitivity around center stick. RC Rate set to one half of the Max Rate is linear. A lower number will reduce sensitivity around center stick. Higher than one half of the Max Rate will also increase the Max Rate.", "Max Rate: Maximum rotation rate at full stick deflection in degrees per second.", "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

data["help"]["table"][6] = {"Rate: Maximum rotation rate at full stick deflection in degrees per second.", "Shape: Shifts the vertex of the control curve. Up to this point, the signal translation is linear. This defines how far the stick travel remains proportional before the curve becomes progressive.", "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

return data
