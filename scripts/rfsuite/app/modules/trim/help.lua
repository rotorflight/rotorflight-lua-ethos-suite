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

data['help']['default'] = {"Link trims: Use to trim out small leveling issues in your swash plate. Typically only used if the swash links are non-adjustable.", "Motorised tail: If using a motorised tail, use this to set the minimum idle speed and zero yaw."}

data['fields'] = {
--    swash_trim_0 = {help ="Swash trim to level the swash plate when using fixed links."},
--    swash_trim_1 = {help ="Swash trim to level the swash plate when using fixed links."},
--    swash_trim_2 = {help ="Swash trim to level the swash plate when using fixed links."},
--    tail_center_trim = {help ="Sets tail rotor trim for 0 yaw for variable pitch, or tail motor throttle for 0 yaw for motorized."},
--    tail_center_trim_motor = {help ="Minimum throttle signal sent to the tail motor. This should be set just high enough that the motor does not stop."}
}

return data
