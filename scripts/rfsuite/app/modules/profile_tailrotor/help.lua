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

data['fields'] = {
    yaw_cw_stop_gain = {t = "Stop gain (PD) for clockwise rotation."},
    yaw_ccw_stop_gain = {t = "Stop gain (PD) for counter-clockwise rotation."},
    yaw_precomp_cutoff = {t = "Frequency limit for all yaw precompensation actions."},
    yaw_cyclic_ff_gain = {t = "Cyclic feedforward mixed into yaw (cyclic-to-yaw precomp)."},
    yaw_collective_ff_gain = {t = "Collective feedforward mixed into yaw (collective-to-yaw precomp)."},
    yaw_collective_dynamic_gain = {t = "An extra boost of yaw precomp on collective input."},
    yaw_collective_dynamic_decay = {t = "Decay time for the extra yaw precomp on collective input."},
    yaw_inertia_precomp_gain = {t = "Scalar gain. The strength of the main rotor inertia. Higher value means more precomp is applied to yaw control."},
    yaw_inertia_precomp_cutoff = {t = "Cutoff. Derivative cutoff frequency in 1/10Hz steps. Controls how sharp the precomp is. Higher value is sharper."}
}

return data
