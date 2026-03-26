--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local flightmode = {}

local runOnce = false

function flightmode.wakeup()

    rfsuite.flightmode.current = "preflight"
    if rfsuite.tasks and rfsuite.tasks.events and rfsuite.tasks.events.flightmode then
      rfsuite.tasks.events.flightmode.reset()
    end

    runOnce = true

end

function flightmode.reset() runOnce = false end

function flightmode.isComplete() return runOnce end

return flightmode
