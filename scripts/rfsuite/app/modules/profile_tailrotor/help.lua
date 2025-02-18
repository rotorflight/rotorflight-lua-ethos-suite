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

data['help']['default'] = {"Yaw Stop Gain: Higher stop gain will make the tail stop more aggressively but may cause oscillations if too high. Adjust CW or CCW to make the yaw stops even.", "Precomp Cutoff: Frequency limit for all yaw precompensation actions.", "Cyclic FF Gain: Tail precompensation for cyclic inputs.", "Collective FF Gain: Tail precompensation for collective inputs.",
                           "Collective Impulse FF: Impulse tail precompensation for collective inputs. If you need extra tail precompensation at the beginning of collective input."}

data['fields'] = {}

return data
