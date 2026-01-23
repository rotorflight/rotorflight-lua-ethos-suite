--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local manifest = {
  [1]  = { name = "onconnect",    connected = false, interval = 0.25, script = "scheduled/onconnect/tasks.lua",            linkrequired = true,  simulatoronly = false, spreadschedule = true  },
  [2]  = { name = "performance",  connected = false, interval = 0.05, script = "scheduled/performance/performance.lua",    linkrequired = false, simulatoronly = false, spreadschedule = true  },
  [3]  = { name = "ini",          connected = true,  interval = -1,   script = "scheduled/ini/ini.lua",                    linkrequired = true,  simulatoronly = false, spreadschedule = true  },
  [4]  = { name = "logging",      connected = true,  interval = 0.5,  script = "scheduled/logging/logging.lua",            linkrequired = false, simulatoronly = false, spreadschedule = true  },
  [5]  = { name = "toolbox",      connected = true,  interval = 0.5,  script = "scheduled/toolbox/toolbox.lua",            linkrequired = true,  simulatoronly = false, spreadschedule = true  },
  [6]  = { name = "adjfunctions", connected = true,  interval = 1.0,  script = "scheduled/adjfunctions/adjfunctions.lua",  linkrequired = true,  simulatoronly = false, spreadschedule = true  },
  [7]  = { name = "events",       connected = false, interval = 0.05, script = "scheduled/events/events.lua",              linkrequired = true,  simulatoronly = false, spreadschedule = true  },
  [8]  = { name = "callback",     connected = false, interval = 0.2,  script = "scheduled/callback/callback.lua",          linkrequired = false, simulatoronly = false, spreadschedule = false },
  [9]  = { name = "simevent",     connected = false, interval = 1,    script = "scheduled/simevent/simevent.lua",          linkrequired = false, simulatoronly = true,  spreadschedule = true  },
  [10] = { name = "telemetry",    connected = false, interval = 0.52, script = "scheduled/telemetry/telemetry.lua",        linkrequired = false, simulatoronly = false, spreadschedule = true  },
  [11] = { name = "developer",    connected = false, interval = -1,   script = "scheduled/developer/developer.lua",        linkrequired = false, simulatoronly = true,  spreadschedule = true  },
  [12] = { name = "logger",       connected = false, interval = 0.28, script = "scheduled/logger/logger.lua",              linkrequired = false, simulatoronly = false, spreadschedule = true  },
  [13] = { name = "sensors",      connected = true,  interval = 0.23, script = "scheduled/sensors/sensors.lua",            linkrequired = true,  simulatoronly = false, spreadschedule = false },
  [14] = { name = "timer",        connected = true,  interval = 0.25, script = "scheduled/timer/timer.lua",                linkrequired = true,  simulatoronly = false, spreadschedule = false },
  [15] = { name = "msp",          connected = false, interval = 0.1,  script = "scheduled/msp/msp.lua",                    linkrequired = false, simulatoronly = false, spreadschedule = false },
}

return manifest