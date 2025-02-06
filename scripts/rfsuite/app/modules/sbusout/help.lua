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

data['help']['default'] = {"Configure advanced mixing and channel mapping if you have SBUS Out enabled on a serial port.", "- For RX channels or servos (wideband), use 1000, 2000 or 500,1000 for narrow band servos.", "- For mixer rules, use -1000, 1000.", "- For motors, use 0, 1000.", "- Or you can customize your own mapping."}

data['fields'] = {sbusOutSource = {t = "Source id for the mix, counting from 0-15."}, sbusOutMin = {t = "The minimum pwm value to send"}, sbusOutMax = {t = "The maximum pwm value to send"}}

return data
