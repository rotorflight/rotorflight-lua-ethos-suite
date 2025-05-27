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
-- Theme initialization table
local init = {
    name = "Developer Refocus Examples",                -- Theme name
    preflight = "preflight.lua",     -- Script to run before takeoff
    inflight = "inflight.lua",       -- Script to run during flight
    postflight = "postflight.lua",   -- Script to run after landing
    wakeup = 0.5,                    -- Interval (seconds) to run wakeup script when display is visible (keep round 0.5 for responsive touch events)
    wakeup_bg = 60,                  -- Interval (seconds) to run wakeup script when display is not visible
    standalone = false,              -- If true, theme handles all rendering itself
    developer = true,                -- If true, theme is in only visible in developer mode
}

return init