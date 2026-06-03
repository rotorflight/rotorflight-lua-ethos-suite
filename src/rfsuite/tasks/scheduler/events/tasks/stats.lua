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
local math_floor = math.floor
local math_abs = math.abs

local rpmStatsReady = false

local function isGovernorAtHeadspeed(value)
    return type(value) == "number" and math_floor(value) == 4
end

local function roundSigned(value)
    if value >= 0 then return math_floor(value + 0.5) end
    return -math_floor(-value + 0.5)
end

local function updateHeadspeedVariance(statsTable, rpm)
    local session = rfsuite.session
    if not session then return end

    local rpmStats = statsTable and statsTable.rpm
    local avg = rpmStats and rpmStats.avg
    if type(rpm) ~= "number" or type(avg) ~= "number" or avg <= 0 then
        session.headspeedVariancePct = nil
        return
    end

    local variancePct = roundSigned((math_abs(rpm - avg) / avg) * 100)
    if session.headspeedVariancePct ~= variancePct then
        session.headspeedVariancePct = variancePct
    end
end

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
        if rfsuite.session then
            rfsuite.session.headspeedVariancePct = nil
        end
        rpmStatsReady = false
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

    local governorValue = telemetry.getSensor("governor")
    if not rpmStatsReady and isGovernorAtHeadspeed(governorValue) then
        if filteredSensors["rpm"] then statsTable["rpm"] = nil end
        rpmStatsReady = true
    end

    if not rpmStatsReady and rfsuite.session then
        rfsuite.session.headspeedVariancePct = nil
    end

    local rpmValue = nil
    for sensorKey, _ in pairs(filteredSensors) do
        local val = sensorKey == "governor" and governorValue or telemetry.getSensor(sensorKey)
        if sensorKey == "rpm" then rpmValue = val end

        if val and type(val) == "number" and (sensorKey ~= "rpm" or rpmStatsReady) then
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

    if rpmStatsReady then
        updateHeadspeedVariance(statsTable, rpmValue)
    end
end

function stats.reset()
    local telemetry = rfsuite.tasks.telemetry
    if telemetry then telemetry.sensorStats = {} end
    if rfsuite.session then
        rfsuite.session.headspeedVariancePct = nil
    end
    fullSensorTable = nil
    filteredSensors = nil
    lastTrackTime = 0
    rpmStatsReady = false
end

return stats
