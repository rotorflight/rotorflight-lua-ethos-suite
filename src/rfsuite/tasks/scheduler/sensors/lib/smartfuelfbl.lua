--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local smartfuelprefs = assert(loadfile("tasks/scheduler/sensors/lib/smartfuelprefs.lua"))()
local smartfuelreserve = assert(loadfile("tasks/scheduler/sensors/lib/smartfuelreserve.lua"))()

local fbl = {}

local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local tonumber = tonumber
local system_getSource = system.getSource

local mirror_sources = {
    sport = {
        smartfuel = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0600},
        smartconsumption = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x5250}
    },
    crsf = {
        smartfuel = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1014},
        smartconsumption = {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1013}
    }
}

local function getProtocol()
    return rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.protocol and rfsuite.tasks.msp.protocol.mspProtocol
end

function fbl.getSource()
    if system.getVersion().simulation == true then
        return nil
    end

    if not rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
        return nil
    end

    local batteryConfig = rfsuite.session and rfsuite.session.batteryConfig
    return batteryConfig and tonumber(batteryConfig.smartfuelRemoteSource)
end

function fbl.isActive()
    local source = fbl.getSource()
    return source ~= nil and source > 0
end

function fbl.getSourceLabel()
    local source = fbl.getSource()
    return source == 1 and "VOLTAGE" or source == 2 and "CURRENT" or source == 3 and "COMBINED" or source == 0 and "OFF" or "n/a"
end

local function getMirrorSensorValue(name)
    local protocol = getProtocol()
    local sources = protocol and mirror_sources[protocol]
    local query = sources and sources[name]
    if not query then return nil end

    local source = system_getSource(query)
    if not source or (source.state and source:state() == false) then
        return nil
    end

    return source:value()
end

function fbl.calculateFuel()
    local rawFuel = getMirrorSensorValue("smartfuel")
    if rawFuel == nil then return nil end

    local fuel = math_floor(math_min(100, math_max(0, rawFuel)) + 0.5)
    local bc = rfsuite.session and rfsuite.session.batteryConfig
    local warningPercent = bc and bc.consumptionWarningPercentage or 0

    return smartfuelreserve.applyPercent(fuel, warningPercent, smartfuelprefs.getEndAtZeroEnabled())
end

function fbl.calculateConsumption()
    return getMirrorSensorValue("smartconsumption")
end

function fbl.reset() end

return fbl
