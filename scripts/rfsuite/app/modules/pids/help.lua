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

data['help']['default'] = {
    "FeedForward (Roll/Pitch): Start at 70, increase until stops are sharp with no drift. Keep roll and pitch equal.",
    "I Gain (Roll/Pitch): Raise gradually for stable piro pitch pumps. Too high causes wobbles; match roll/pitch values.",
    "Tail P/I/D Gains: Increase P until slight wobble in funnels, then back off slightly. Raise I until tail holds firm in hard moves (too high causes slow wag). Adjust D for smooth stops—higher for slow servos, lower for fast ones.",
    "Tail Stop Gain (CW/CCW): Adjust separately for clean, bounce-free stops in both directions.",
    "Test & Adjust: Fly, observe, and fine-tune for best performance in real conditions."
}

data['fields'] = {
    profilesProportional = {t = "How tightly the system tracks the desired setpoint."},
    profilesIntegral = {t = "How tightly the system holds its position."},
    profilesHSI = {t = "Used to prevent the craft from pitching up when flying at speed."},
    profilesDerivative = {t = "Strength of dampening to any motion on the system, including external influences. Also reduces overshoot."},
    profilesFeedforward = {t = "Helps push P-term based on stick input. Increasing will make response more sharp, but can cause overshoot."},
    profilesBoost = {t = "Additional boost on the feedforward to make the heli react more to quick stick movements."}
}

return data
