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
    interval        = 0.28,         -- run every 0.28 seconds
    script          = "logger.lua", -- run this script
    linkrequired    = false,        -- run this script only if link is established
    connected       = false,         -- run this script only if msp is connected
    spreadschedule  = true,         -- run on every loop
    simulatoronly   = true,         -- run this script in simulation mode
}

return init
