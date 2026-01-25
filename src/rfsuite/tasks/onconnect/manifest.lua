--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- On-connect tasks now run strictly in the order listed below.
-- Keep critical/fast tasks at the top (e.g. API version, clock sync).
--
-- NOTE: heavier, non-critical reads have been moved to tasks/postconnect so we can
--       set rfsuite.session.isConnected sooner and close the loader earlier.

return {
    { name = "apiversion" },
    { name = "fcversion" },
    { name = "uid" },
    { name = "modelpreferences" },
    { name = "sensorstats" },
    { name = "timer" },
    { name = "rateprofile" },     
    { name = "battery" },        
}
