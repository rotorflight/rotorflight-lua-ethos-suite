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
    interval = 0.1, -- run at least every 0.1s
    priority = 4, -- medium priority.  1 = low , 2 = medium, 3 = high, etc
    script = "msp.lua", -- run this script
    msp = true, -- do not run if busy with msp [as this is msp we set to true as must run]
    always_run = true, -- run on every loop
}
return init
