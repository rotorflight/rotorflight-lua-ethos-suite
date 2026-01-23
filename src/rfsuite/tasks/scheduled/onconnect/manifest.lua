--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    -- HIGH priority (must complete early)
    { name = "apiversion",        level = "high" },
    { name = "clocksync",         level = "high" },
    { name = "fcversion",         level = "high" },
    { name = "uid",               level = "high" },

    -- MEDIUM priority
    { name = "modelpreferences",  level = "medium" },
    { name = "servos",            level = "medium" },
    { name = "tailmode",          level = "medium" },
    { name = "rxmap",             level = "medium" },
    { name = "governor",          level = "medium" },
    { name = "telemetryconfig",   level = "medium" },

    -- LOW priority / background
    { name = "battery",           level = "low" },
    { name = "craftname",         level = "low" },
    { name = "sensorstats",       level = "low" },
    { name = "syncstats",         level = "low" },
    { name = "timer",             level = "low" },
    { name = "rateprofile",       level = "low" },
}
