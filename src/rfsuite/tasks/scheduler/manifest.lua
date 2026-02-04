--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local manifest = {

  -- High-frequency performance metrics collection
  [1]  = { name = "performance",  connected = false, interval = 0.05, script = "scheduler/performance/performance.lua",    linkrequired = false, simulatoronly = false, spreadschedule = true  },

  -- INI handling (currently disabled)
  [2]  = { name = "ini",          connected = true,  interval = -1,   script = "scheduler/ini/ini.lua",                    linkrequired = true,  simulatoronly = false, spreadschedule = true  },

  -- Periodic logging; runs below 1s to ensure 1Hz log capture
  [3]  = { name = "logging",      connected = true,  interval = 0.5,  script = "scheduler/logging/logging.lua",            linkrequired = false, simulatoronly = false, spreadschedule = true  },

  -- Lightweight UI utilities; balanced for responsiveness
  [4]  = { name = "toolbox",      connected = true,  interval = 0.5,  script = "scheduler/toolbox/toolbox.lua",            linkrequired = true,  simulatoronly = false, spreadschedule = true  },

  -- Adjustment logic (rates, trims, etc.); low-frequency by design
  [5]  = { name = "adjfunctions", connected = true,  interval = 1.0,  script = "scheduler/adjfunctions/adjfunctions.lua",  linkrequired = true,  simulatoronly = false, spreadschedule = true  },

  -- Core event dispatch; runs fast for timely state changes
  [6]  = { name = "events",       connected = false, interval = 0.05, script = "scheduler/events/events.lua",              linkrequired = true,  simulatoronly = false, spreadschedule = true  },

  -- User callback hooks; background execution at moderate rate
  [7]  = { name = "callback",     connected = false, interval = 0.2,  script = "scheduler/callback/callback.lua",          linkrequired = false, simulatoronly = false, spreadschedule = false },

  -- Simulator-only event handling
  [8]  = { name = "simevent",     connected = false, interval = 1.0,  script = "scheduler/simevent/simevent.lua",          linkrequired = false, simulatoronly = true,  spreadschedule = true  },

  -- Telemetry aggregation and publishing
  [9]  = { name = "telemetry",    connected = false, interval = 0.52, script = "scheduler/telemetry/telemetry.lua",        linkrequired = false, simulatoronly = false, spreadschedule = true  },

  -- Developer utilities (disabled by default)
  [10] = { name = "developer",    connected = false, interval = -1,   script = "scheduler/developer/developer.lua",        linkrequired = false, simulatoronly = true,  spreadschedule = true  },

  -- Log output task; internally rate-limited
  [11] = { name = "logger",       connected = false, interval = 0.28, script = "scheduler/logger/logger.lua",              linkrequired = false, simulatoronly = false, spreadschedule = true  },

  -- Sensor polling; runs frequently to keep data fresh
  [12] = { name = "sensors",      connected = true,  interval = 0.23, script = "scheduler/sensors/sensors.lua",            linkrequired = true,  simulatoronly = false, spreadschedule = false },

  -- Timer service; must tick faster than 0.5s for accuracy
  [13] = { name = "timer",        connected = true,  interval = 0.25, script = "scheduler/timer/timer.lua",                linkrequired = true,  simulatoronly = false, spreadschedule = false },

  -- MSP processing; adaptive internally, with boost during active traffic
  [14] = { name = "msp",          connected = false, interval = 0.2,  script = "scheduler/msp/msp.lua",                    linkrequired = false, simulatoronly = false, spreadschedule = false },
}

return manifest
