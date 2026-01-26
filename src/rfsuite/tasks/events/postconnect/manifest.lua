--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- Post-connect tasks run AFTER the core link is established (rfsuite.session.isConnected == true).
-- Use this for heavier reads that are not required to close the loader quickly.

return {
    { name = "clocksync" },  
    { name = "servos" },
    { name = "tailmode" },
    { name = "governor" },
    { name = "craftname" },
    { name = "rxmap" },    
    { name = "syncstats" },    
}
