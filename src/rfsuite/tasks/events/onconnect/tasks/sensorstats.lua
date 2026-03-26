--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local sensorstats = {}

local runOnce = false

function sensorstats.wakeup()

    if rfsuite.session.apiVersion == nil then return end

    if rfsuite.session.mspBusy then return end

    if rfsuite.tasks.telemetry then
        rfsuite.tasks.telemetry.sensorStats = {}
        runOnce = true
    end
end

function sensorstats.reset() runOnce = false end

function sensorstats.isComplete() return runOnce end

return sensorstats
