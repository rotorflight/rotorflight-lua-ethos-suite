--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local timer = {}
local floor = math.floor
local format = string.format

local lastSeconds = nil
local lastDisplay = "00:00"

function timer.wakeup()
    local session = rfsuite.session
    local timerSession = session and session.timer
    local value = timerSession and timerSession.live

    if type(value) ~= "number" or value < 0 then
        value = 0
    end

    local wholeSeconds = floor(value + 0.5)
    if wholeSeconds ~= lastSeconds then
        local minutes = floor(wholeSeconds / 60)
        local seconds = wholeSeconds % 60
        lastDisplay = format("%02d:%02d", minutes, seconds)
        lastSeconds = wholeSeconds
    end

    session.toolbox.timer = lastDisplay
end

return timer
