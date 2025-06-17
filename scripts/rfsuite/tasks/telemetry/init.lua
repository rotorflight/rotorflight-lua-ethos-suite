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
    intmin    = 0.025,                  -- minimum number of seconds to wait between runs (i.e. don’t run more often than every 0.25s)
    intmax    = 0.1,                    -- maximum number of seconds to wait between runs (i.e. ensure it runs at least once every 0.5s)
    priority  = 2,                      -- scheduling priority (1 = low, 2 = medium, 3 = high, etc.)
    script    = "telemetry.lua",        -- the task’s entry-point script
    isolate   = { msp = true },         -- table of peer tasks not to run in the same cycle
    nolink    = true,                   -- if true, runs even when the telemetry link is down
}

return init
