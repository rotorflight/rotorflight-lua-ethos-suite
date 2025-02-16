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

data['help']['default'] = {"Full headspeed: Headspeed target when at 100% throttle input.", "PID master gain: How hard the governor works to hold the RPM.", "Gains: Fine tuning of the governor.", "Precomp: Governor precomp gain for yaw, cyclic, and collective inputs.", "Max throttle: The maximum throttle % the governor is allowed to use.",
                           "Tail Torque Assist: For motorized tails. Gain and limit of headspeed increase when using main rotor torque for yaw assist."}

data['fields'] = {}

return data
