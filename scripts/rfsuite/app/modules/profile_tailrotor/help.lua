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
    profilesYawStopGainCW = {t = "Stop gain (PD) for clockwise rotation."},
    profilesYawStopGainCCW = {t = "Stop gain (PD) for counter-clockwise rotation."},
    profilesYawPrecompCutoff = {t = "Frequency limit for all yaw precompensation actions."},
    profilesYawFFCyclicGain = {t = "Cyclic feedforward mixed into yaw (cyclic-to-yaw precomp)."},
    profilesYawFFCollectiveGain = {t = "Collective feedforward mixed into yaw (collective-to-yaw precomp)."},
    profilesYawFFImpulseGain = {t = "An extra boost of yaw precomp on collective input."},
    profilesyawFFImpulseDecay = {t = "Decay time for the extra yaw precomp on collective input."},
    profilesIntertiaGain = {t = "Scalar gain. The strength of the main rotor inertia. Higher value means more precomp is applied to yaw control."},
    profilesInertiaCutoff = {t = "Cutoff. Derivative cutoff frequency in 1/10Hz steps. Controls how sharp the precomp is. Higher value is sharper."}
}

return data
