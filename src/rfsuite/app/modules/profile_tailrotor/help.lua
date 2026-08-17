--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


local data = {}

data['help'] = {}

local defaultHelp = {
    "Yaw Stop Gain: Higher stop gain will make the tail stop more aggressively but may cause oscillations if too high. Adjust CW or CCW to make the yaw stops even.",
    "Precomp Cutoff: Frequency limit for all yaw precompensation actions.",
    "Cyclic FF Gain: Tail precompensation for cyclic inputs.",
    "Collective FF Gain: Tail precompensation for collective inputs."
}

if rfsuite.utils.apiVersionCompare("<=", {12, 0, 7}) then
    defaultHelp[#defaultHelp + 1] = "Collective Impulse FF: Impulse tail precompensation for collective inputs. If you need extra tail precompensation at the beginning of collective input."
end

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    defaultHelp[#defaultHelp + 1] = "Tail Torque Assist: For motorized tails. Gain and limit of headspeed increase when using main rotor torque for yaw assist."
end

data['help']['default'] = defaultHelp

data['fields'] = {}

return data
