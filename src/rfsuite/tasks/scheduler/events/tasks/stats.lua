--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local stats = {}

local fullSensorTable = nil
local filteredSensors = nil
local lastTrackTime = 0

local os_clock = os.clock
local math_huge = math.huge

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

    local telemetry = rfsuite.tasks.telemetry
    if not telemetry then return end

    if rfsuite.flightmode.current ~= "inflight" then
        inflightStartTime = nil
        rpmReset = false
        return
    end

    local now = os_clock()
    if now - lastTrackTime < 0.25 then return end
    lastTrackTime = now

    if not fullSensorTable then
        fullSensorTable = telemetry.sensorTable
        if not fullSensorTable then return end
        buildFilteredList()
    end

    local statsTable = telemetry.sensorStats
    if not statsTable then
        statsTable = {}
        telemetry.sensorStats = statsTable
    end

    if not inflightStartTime then
        inflightStartTime = now
        rpmReset = false
    end

    if not rpmReset and (now - inflightStartTime >= rpmStatDelay) then
        if filteredSensors["rpm"] then statsTable["rpm"] = nil end
        rpmReset = true
    end

    for sensorKey, _ in pairs(filteredSensors) do
        local val = telemetry.getSensor(sensorKey)

        if val and type(val) == "number" then
            local entry = statsTable[sensorKey]
            if not entry then
                entry = {min = math_huge, max = -math_huge, sum = 0, count = 0, avg = 0}
                statsTable[sensorKey] = entry
            end

            if val < entry.min then entry.min = val end
            if val > entry.max then entry.max = val end
            entry.sum = entry.sum + val
            entry.count = entry.count + 1
            entry.avg = entry.sum / entry.count
        end
    end
end

function stats.reset()
    local telemetry = rfsuite.tasks.telemetry
    if telemetry then telemetry.sensorStats = {} end
    fullSensorTable = nil
    filteredSensors = nil
    lastTrackTime = 0
    inflightStartTime = nil
    rpmReset = false
end

return stats
