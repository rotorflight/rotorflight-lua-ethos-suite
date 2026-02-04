--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local manifest = {

  -- performance monitoring runs very fast to capture detailed performance metrics
  [1]  = { name = "performance",  connected = false, interval = 0.05, script = "scheduler/performance/performance.lua",    linkrequired = false, simulatoronly = false, spreadschedule = true  },

  -- disabled as not used currently
  [2]  = { name = "ini",          connected = true,  interval = -1,   script = "scheduler/ini/ini.lua",                    linkrequired = true,  simulatoronly = false, spreadschedule = true  },

  -- logging must run at less than 1s to ensure we capture the logs every 1s
  [3]  = { name = "logging",      connected = true,  interval = 0.5,  script = "scheduler/logging/logging.lua",            linkrequired = false, simulatoronly = false, spreadschedule = true  },

  -- toolbox runs at 2Hz to provide responsive user interface without overloading the system  Its a light weight tasks
  [4]  = { name = "toolbox",      connected = true,  interval = 0.5,  script = "scheduler/toolbox/toolbox.lua",            linkrequired = true,  simulatoronly = false, spreadschedule = true  },

  -- adjustment functions run at 1Hz to provide timely control adjustments without overloading the system
  [5]  = { name = "adjfunctions", connected = true,  interval = 1.0,  script = "scheduler/adjfunctions/adjfunctions.lua",  linkrequired = true,  simulatoronly = false, spreadschedule = true  },

  -- event handling runs fast to ensure timely response to critical events
  [6]  = { name = "events",       connected = false, interval = 0.05, script = "scheduler/events/events.lua",              linkrequired = true,  simulatoronly = false, spreadschedule = true  },

  -- callback task for user scripts; runs at 5Hz and handled background processing
  [7]  = { name = "callback",     connected = false, interval = 0.2,  script = "scheduler/callback/callback.lua",          linkrequired = false, simulatoronly = false, spreadschedule = false },

  -- simulation event handling; runs at 1Hz
  [8]  = { name = "simevent",     connected = false, interval = 1,    script = "scheduler/simevent/simevent.lua",          linkrequired = false, simulatoronly = true,  spreadschedule = true  },

  -- telemetry runs at ~2Hz to balance timely updates with performance
  [9]  = { name = "telemetry",    connected = false, interval = 0.52, script = "scheduler/telemetry/telemetry.lua",        linkrequired = false, simulatoronly = false, spreadschedule = true  },

  -- disabled with -1 interval; enable for development builds
  [10]  = { name = "developer",    connected = false, interval = -1,   script = "scheduler/developer/developer.lua",        linkrequired = false, simulatoronly = true,  spreadschedule = true  },

  -- this tasks prints log messages- it runs fast; but has its own internal rate limiting
  [11]  = { name = "logger",       connected = false, interval = 0.28, script = "scheduler/logger/logger.lua",              linkrequired = false, simulatoronly = false, spreadschedule = true  },

  -- sensors must run fast and consistently to ensure data is fresh for other tasks
  [12]  = { name = "sensors",      connected = true,  interval = 0.23, script = "scheduler/sensors/sensors.lua",            linkrequired = true,  simulatoronly = false, spreadschedule = false },

  -- To ensure accurate timer this must tick faster than 0.5s.  
  [13]  = { name = "timer",        connected = true,  interval = 0.25, script = "scheduler/timer/timer.lua",                linkrequired = true,  simulatoronly = false, spreadschedule = false },

  -- this fires slower than expected by design.  it has a 'boost' mode when msp activity is detected
  [14]  = { name = "msp",          connected = false, interval = 0.2,  script = "scheduler/msp/msp.lua",                    linkrequired = false, simulatoronly = false, spreadschedule = false }, 
}

return manifest
