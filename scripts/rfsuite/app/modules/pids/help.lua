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

data['help']['default'] = {"Increase D, P, I in order until each wobbles, then back off.", "Set F for a good response in full stick flips and rolls.", "If necessary, tweak P:D ratio to set response damping to your liking.", "Increase O until wobbles occur when jabbing elevator at full collective, back off a bit.", "Increase B if you want sharper response."}

data['fields'] = {
    profilesProportional = {t = "How tightly the system tracks the desired setpoint."},
    profilesIntegral = {t = "How tightly the system holds its position."},
    profilesHSI = {t = "Used to prevent the craft from pitching up when flying at speed."},
    profilesDerivative = {t = "Strength of dampening to any motion on the system, including external influences. Also reduces overshoot."},
    profilesFeedforward = {t = "Helps push P-term based on stick input. Increasing will make response more sharp, but can cause overshoot."},
    profilesBoost = {t = "Additional boost on the feedforward to make the heli react more to quick stick movements."}
}

return data
