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

data['help']['default'] = {"Collective Pitch Compensation: Increasing will compensate for the pitching motion caused by tail drag when climbing.", "Cross Coupling Gain: Removes roll coupling when only elevator is applied.", "Cross Coupling Ratio: Amount of compensation (pitch vs roll) to apply.",
                           "Cross Coupling Feq. Limit: Frequency limit for the compensation, higher value will make the compensation action faster."}

data['fields'] = {
    pitch_collective_ff_gain = {t = "Increasing will compensate for the pitching up motion caused by tail drag when climbing."},
    cyclic_cross_coupling_gain = {t = "Amount of compensation applied for pitch-to-roll decoupling."},
    cyclic_cross_coupling_ratio = {t = "Amount of roll-to-pitch compensation needed, vs. pitch-to-roll."},
    cyclic_cross_coupling_cutoff = {t = "Frequency limit for the compensation. Higher value will make the compensation action faster."}
}

return data
