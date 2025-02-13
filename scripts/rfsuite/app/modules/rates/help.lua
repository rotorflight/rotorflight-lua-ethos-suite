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

data['help']['default'] = {"Default: We keep this to make button appear for rates.", "We will use the sub keys below."}

-- Rates is a bit of an odd-ball because we show different help based one
-- the rate table selected.  This info is supplied below.

data["help"]["table"] = {}

-- RATE TABLE NONE
data["help"]["table"][0] = {"All values are set to zero because no RATE TABLE is in use."}

-- RATE TABLE BETAFLIGHT
data["help"]["table"][1] = {"RC Rate: Maximum rotation rate at full stick deflection.", "SuperRate: Increases maximum rotation rate while reducing sensitivity around half stick.", "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

-- RATE TABLE RACEFLIGHT
data["help"]["table"][2] = {"Rate: Maximum rotation rate at full stick deflection in degrees per second.", "Acro+: Increases the maximum rotation rate while reducing sensitivity around half stick.", "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

-- RATE TABLE KISS
data["help"]["table"][3] = {"RC Rate: Maximum rotation rate at full stick deflection.", "Rate: Increases maximum rotation rate while reducing sensitivity around half stick.", "RC Curve: Reduces sensitivity near the stick's center where fine controls are needed."}

-- RATE TABLE ACTUAL
data["help"]["table"][4] = {"Center Sensitivity: Use to reduce sensitivity around center stick. Set Center Sensitivity set to the same as Max Rate for a linear response. A lower number than Max Rate will reduce sensitivity around center stick. Note that higher than Max Rate will increase the Max Rate - not recommended as it causes issues in the Blackbox log.",
                            "Max Rate: Maximum rotation rate at full stick deflection in degrees per second.", "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

-- RATE TABLE QUICK
data["help"]["table"][5] = {"RC Rate: Use to reduce sensitivity around center stick. RC Rate set to one half of the Max Rate is linear. A lower number will reduce sensitivity around center stick. Higher than one half of the Max Rate will also increase the Max Rate.", "Max Rate: Maximum rotation rate at full stick deflection in degrees per second.",
                            "Expo: Reduces sensitivity near the stick's center where fine controls are needed."}

return data
