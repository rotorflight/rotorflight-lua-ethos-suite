--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {name = "Basic Timer", preflight = "timer.lua", inflight = "timer.lua", postflight = "timer.lua", configure = "configure.lua", standalone = false}

return init
