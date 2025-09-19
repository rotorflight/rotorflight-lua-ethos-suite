--[[
 * Smart sensor aggregator for Rotorflight
 *
 * This module registers two custom telemetry sensors with the transmitter:
 *
 *  • **Smart Fuel** (`appId` 0x5FE1, unit = `UNIT_PERCENT`):
 *      - Provides an estimate of the remaining pack capacity as a percentage.
 *      - If `modelPreferences.battery.calc_local == 1` it calls into
 *        `smartfuelvoltage.lua` to derive the percentage from battery voltage.
 *        Otherwise it delegates to `smartfuel.lua`, which reads the flight
 *        controller’s mAh–based fuel estimator.
 *
 *  • **Smart Consumption** (`appId` 0x5FE0, unit = `UNIT_MILLIAMPERE_HOUR`):
 *      - Reports the estimated capacity consumed in milliamp‑hours.
 *      - When `calc_local == 1` it computes consumption from the Smart Fuel
 *        percentage: it multiplies the used percentage by the configured
 *        `batteryCapacity` and accounts for the `consumptionWarningPercentage`
 *        reserve.  If `calc_local` is not set, it simply exposes the flight
 *        controller’s “consumption” telemetry sensor.
 *
 * The script wakes once per `interval` (default = 1 s) in `smart.wakeup()` to
 * recompute sensor values and update or reset each FrSky DIY sensor.  Sensor
 * definitions are held in the `smart_sensors` table; the helper
 * `createOrUpdateSensor()` creates sensors on first use and caches them in
 * `sensorCache`.  The `resetFuel()` function clears state in the imported fuel
 * modules when a new pack is installed.
 *
 * See the entries in `smart_sensors` for names, `appId`s and units.  Only the
 * two sensors above are currently defined, but additional sensors could be
 * added in the same fashion.


 * Possible sensor ids we can use are.
 * 0x5FE1   - smartfuel
 * 0x5FE0   - smartconsumption
 * 0x5FDF
 * 0x5FDE
 * 0x5FDD
 * 0x5FDC
 * 0x5FDB
 * 0x5FDA
 * 0x5FD9
 * 0x5FD8
 * 0x5FD7
 * 0x5FD6
 * 0x5FD5
 * 0x5FD4
 * 0x5FD3
 * 0x5FD2
 * 0x5FD1
 * 0x5FD0
 * 0x5FCF
 * 0x5FCE

]]

local smart = {}

local smartfuel = assert(rfsuite.compiler.loadfile("tasks/sensors/lib/smartfuel.lua"))()
local smartfuelvoltage = assert(rfsuite.compiler.loadfile("tasks/sensors/lib/smartfuelvoltage.lua"))()

-- container vars
local log
local tasks 

local interval = 1 
local lastWake = os.clock()
local telemetry
local firstWakeup = true

-- Caches & state tracking
local sensorCache = {}
local negativeCache = {}      -- appId -> true when system.getSource() returned nil (avoid re-query thrash)
local lastValue = {}          -- appId -> last numeric value pushed to TX
local lastPush = {}           -- appId -> last os.clock() time we pushed any value
local lastModule = nil        -- detect module changes to rebind DIY sensors
local VALUE_EPSILON = 0.0     -- push on any change; keep 0 to avoid stale warnings
local FORCE_REFRESH_INTERVAL = 2.5  -- seconds; force a heartbeat write this often even if unchanged

local function calculateFuel()
    -- work out what type of sensor we are running and use 
    -- the appropriate calculation method
    if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.calc_local then
         if rfsuite.session.modelPreferences.battery.calc_local == 1 then
            return smartfuelvoltage.calculate()
         else
            return smartfuel.calculate()
         end
    else
            return smartfuel.calculate()
    end

end

local function calculateConsumption()
            -- If smartvoltage is enabled, calculate mAh used based on capacity
            if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.calc_local then
                if rfsuite.session.modelPreferences.battery.calc_local == 1 then
                    local capacity = (rfsuite.session.batteryConfig and rfsuite.session.batteryConfig.batteryCapacity) or 1000 -- Default to 1000mAh if not set
                    local smartfuelPct = rfsuite.tasks.telemetry.getSensor("smartfuel")
                    local warningPercentage = (rfsuite.session.batteryConfig and rfsuite.session.batteryConfig.consumptionWarningPercentage) or 30
                    if smartfuelPct then
                        local usableCapacity = capacity * (1 - warningPercentage / 100)
                        local usedPercent = 100 - smartfuelPct -- how much has been used
                        return (usedPercent / 100) * usableCapacity
                    end
                else
                    -- fallback to FC "consumption"
                    return rfsuite.tasks.telemetry.getSensor("consumption") or 0
                end
            else
                -- No battery prefs — fallback to FC "consumption"
                return rfsuite.tasks.telemetry.getSensor("consumption") or 0
            end
end    

local function resetFuel()
    smartfuel.reset()
    smartfuelvoltage.reset()
end


local function clamp(v, minv, maxv)
    if v == nil then return nil end
    if v < minv then return minv elseif v > maxv then return maxv else return v end
end

local function resetConsumption()
    --- just a stub atm
end


local smart_sensors = {
    smartfuel = {
        name = "Smart Fuel",
        appId = 0x5FE1, -- Unique sensor ID
        unit = UNIT_PERCENT, -- Telemetry unit
        minimum = 0,
        maximum = 100,
        value = calculateFuel,
    },
    smartconsumption = {
        name = "Smart Consumption",
        appId = 0x5FE0, -- Unique sensor ID
        unit = UNIT_MILLIAMPERE_HOUR, -- Telemetry unit
        minimum = 0,
        maximum = 1000000000,
        value = calculateConsumption,
    },    
}

smart.sensors = smart_sensors

local function createOrUpdateSensor(appId, fieldMeta, value)
    -- If module changed, invalidate cache so sensors rebind correctly
    local currentModule = rfsuite.session.telemetrySensor and rfsuite.session.telemetrySensor:module()
    if lastModule ~= currentModule then
        sensorCache = {}
        negativeCache = {}
        lastModule = currentModule
    end

    -- Negative cache: if we previously saw no source for this appId, skip lookup this tick
    if sensorCache[appId] == nil and negativeCache[appId] then
        -- nothing to do this time
    end

    if not sensorCache[appId] and not negativeCache[appId] then
        local existingSensor = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = appId })
        if existingSensor then
            sensorCache[appId] = existingSensor
        else
            if not rfsuite.session.telemetrySensor then
                negativeCache[appId] = true
                return
            end
            local sensor = model.createSensor({type=SENSOR_TYPE_DIY})
            sensor:name(fieldMeta.name)
            sensor:appId(appId)
            sensor:physId(0)
            sensor:module(rfsuite.session.telemetrySensor:module())

            if fieldMeta.unit then
                sensor:unit(fieldMeta.unit)
                sensor:protocolUnit(fieldMeta.unit)
            end
            sensor:minimum(fieldMeta.minimum or -1000000000)
            sensor:maximum(fieldMeta.maximum or 1000000000)

            sensorCache[appId] = sensor
        end
        if not sensorCache[appId] then negativeCache[appId] = true end
    end

    -- Push or reset value. To avoid TX sensor warnings, we periodically force a write even if unchanged.
    if value ~= nil then
        local minv = fieldMeta.minimum or -1000000000
        local maxv = fieldMeta.maximum or 1000000000
        local v = clamp(value, minv, maxv)
        local last = lastValue[appId]
        local now = os.clock()
        local stale = (now - (lastPush[appId] or 0)) >= FORCE_REFRESH_INTERVAL
        if last == nil or math.abs(v - last) >= VALUE_EPSILON or stale then
            sensorCache[appId]:value(v)
            lastValue[appId] = v
            lastPush[appId] = now
        end
    else
        sensorCache[appId]:reset()
        lastValue[appId] = nil
        lastPush[appId] = os.clock()
    end
end


local lastWakeupTime = 0
function smart.wakeup()

    -- we cannot do anything until connected
    if not rfsuite.session.isConnected then return end    
    if rfsuite.session.mspBusy then return end
    if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then
        return
    end     

    if firstWakeup then
        log = rfsuite.utils.log
        tasks = rfsuite.tasks
        firstWakeup = false
    end

    -- If telemetry is inactive, clear caches & bail
    if not (rfsuite.session.telemetryState and rfsuite.session.telemetrySensor) then
        sensorCache = {}
        negativeCache = {}
        lastValue = {}
        return
    end

    -- rate-limit: bail out until interval has elapsed
    if (os.clock() - lastWake) < interval then
        return
    end
    lastWake = os.clock()

    for name, meta in pairs(smart_sensors) do
        local value
        if type(meta.value) == "function" then
            value = meta.value()
        else
            value = meta.value  -- Assume value is already calculated
        end
        createOrUpdateSensor(meta.appId, meta, value)
    end
end

function smart.reset()
    sensorCache = {}
    negativeCache = {}
    lastValue = {}
    lastPush = {}
    lastModule = nil

    resetFuel()
    resetConsumption()

end

return smart
