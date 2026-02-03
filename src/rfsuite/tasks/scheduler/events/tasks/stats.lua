--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local config = arg[1]

local stats = {}

local fullSensorTable = nil
local filteredSensors = nil
local lastTrackTime = 0

local telemetry

local inflightStartTime = nil
local rpmStatDelay = 15
local rpmReset = false

local function buildFilteredList()
    filteredSensors = {}

    for sensorKey, sensorDef in pairs(fullSensorTable) do
        local mt = sensorDef.stats

        if mt == true then
            filteredSensors[sensorKey] = sensorDef

        elseif type(mt) == "function" then
            if mt() then
                filteredSensors[sensorKey] = sensorDef
            end
        end
    end
end


function stats.wakeup()

    if not telemetry then
        telemetry = rfsuite.tasks.telemetry
        return
    end

    if rfsuite.flightmode.current ~= "inflight" then
        inflightStartTime = nil
        rpmReset = false
        return
    end

    local now = os.clock()
    if now - lastTrackTime < 0.25 then return end
    lastTrackTime = now

    if not fullSensorTable then
        fullSensorTable = telemetry.sensorTable
        if not fullSensorTable then return end
        buildFilteredList()
    end

    if not telemetry.sensorStats then telemetry.sensorStats = {} end

    if not inflightStartTime then
        inflightStartTime = now
        rpmReset = false
    end

    local statsTable = telemetry.sensorStats

    for sensorKey, _ in pairs(filteredSensors) do
        local val = telemetry.getSensor(sensorKey)

        if sensorKey == "rpm" then
            if not rpmReset and now - inflightStartTime >= rpmStatDelay then
                statsTable[sensorKey] = nil
                rpmReset = true
            end
        end

        if val and type(val) == "number" then
            if not statsTable[sensorKey] then statsTable[sensorKey] = {min = math.huge, max = -math.huge, sum = 0, count = 0, avg = 0} end

            local entry = statsTable[sensorKey]
            entry.min = math.min(entry.min, val)
            entry.max = math.max(entry.max, val)
            entry.sum = entry.sum + val
            entry.count = entry.count + 1
            entry.avg = entry.sum / entry.count
        end
    end
end

function stats.reset()
    if telemetry then telemetry.sensorStats = {} end
    fullSensorTable = nil
    filteredSensors = nil
    lastTrackTime = 0
    inflightStartTime = nil
    rpmReset = false
end

return stats
