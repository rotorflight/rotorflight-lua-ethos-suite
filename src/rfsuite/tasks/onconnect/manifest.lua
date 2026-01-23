--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- On-connect tasks now run strictly in the order listed below.
-- Keep critical/fast tasks at the top (e.g. API version, clock sync).

return {
    { name = "apiversion" },
    { name = "clocksync" },
    { name = "fcversion" },
    { name = "uid" },

    { name = "modelpreferences" },
    { name = "servos" },
    { name = "tailmode" },
    { name = "rxmap" },
    { name = "governor" },
    { name = "telemetryconfig" },

    { name = "battery" },
    { name = "craftname" },
    { name = "sensorstats" },
    { name = "syncstats" },
    { name = "timer" },
    { name = "rateprofile" },
}
