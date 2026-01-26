--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local timer = {}

local runOnce = false

function timer.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end

    rfsuite.session.timer = {}
    rfsuite.session.timer.start = nil
    rfsuite.session.timer.live = nil
    rfsuite.session.timer.lifetime = nil
    rfsuite.session.timer.session = 0
    runOnce = true

end

function timer.reset() runOnce = false end

function timer.isComplete() return runOnce end

return timer
