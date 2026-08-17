--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --


local data = {}

data['help'] = {}

data['help']['default'] = {"Full headspeed: Headspeed target when at 100% throttle input.", "PID master gain: How hard the governor works to hold the RPM.", "Gains: Fine tuning of the governor.", "Precomp: Governor precomp gain for yaw, cyclic, and collective inputs.", "Max throttle: The maximum throttle % the governor is allowed to use.", "Tail Torque Assist: For motorized tails. Gain and limit of headspeed increase when using main rotor torque for yaw assist."}

data['fields'] = {}

return data
