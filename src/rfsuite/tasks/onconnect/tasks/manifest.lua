--[[
  Auto-generated/maintained manifest for onconnect tasks.
  Keeps runtime disk I/O low by avoiding directory scans.

  Each entry:
    file:  task lua filename WITHOUT .lua
    level: "high" | "medium" | "low"
]]

return {
  -- high priority (must complete before moving to preflight)
  { file = "apiversion",       level = "high" },
  { file = "clocksync",        level = "high" },
  { file = "fcversion",        level = "high" },
  { file = "modelpreferences", level = "high" },
  { file = "sensorstats",      level = "high" },
  { file = "telemetryconfig",  level = "high" },
  { file = "timer",            level = "high" },
  { file = "uid",              level = "high" },

  -- medium priority
  { file = "battery",          level = "medium" },
  { file = "craftname",        level = "medium" },
  { file = "syncstats",        level = "medium" },

  -- low priority
  { file = "governor",         level = "low" },
  { file = "rxmap",            level = "low" },
  { file = "servos",           level = "low" },
  { file = "tailmode",         level = "low" },
}
