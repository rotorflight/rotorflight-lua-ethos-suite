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
local init = {
    intmin = 0.001, -- run at least every 0.1s
    intmax = 0.025, -- run at least every 0.1s
    priority = 2, -- medium priority.  1 = low , 2 = medium, 3 = high, etc
    script = "telemetry.lua", -- run this script
    msp = false, -- do not run if busy with msp 
    no_link = false -- run this script always
}
return init
