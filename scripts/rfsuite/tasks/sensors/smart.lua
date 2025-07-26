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

function calculateConsumption()
            -- If local calculation is enabled, calculate mAh used based on capacity
            if rfsuite.session.modelPreferences and rfsuite.session.modelPreferences.battery and rfsuite.session.modelPreferences.battery.calc_local then
                if rfsuite.session.modelPreferences.battery.calc_local == 1 then
                    local capacity = rfsuite.session.batteryConfig.batteryCapacity or 1000 -- Default to 1000mAh if not set
                    local smartfuelPct = rfsuite.tasks.telemetry.getSensor("smartfuel")
                    local warningPercentage = rfsuite.session.batteryConfig.consumptionWarningPercentage or 30
                    if smartfuelPct then
                        local usableCapacity = capacity * (1 - warningPercentage / 100)
                        local usedPercent = 100 - smartfuelPct -- how much has been used
                        return (usedPercent / 100) * usableCapacity
                    end
                else
                    return nil    
                end
            else
                    return rfsuite.tasks.telemetry.getSensor("consumption") or 0
            end
end    

local function resetFuel()
    smartfuel.reset()
    smartfuelvoltage.reset()
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
local sensorCache = {}

local function createOrUpdateSensor(appId, fieldMeta, value)
    if not sensorCache[appId] then
        local existingSensor = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = appId })

        if existingSensor then
            sensorCache[appId] = existingSensor
        else
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
    end

    if value then
        sensorCache[appId]:value(value)
    else
        sensorCache[appId]:reset()    
    end
end


local lastWakeupTime = 0
function smart.wakeup()

    if firstWakeup then
        log = rfsuite.utils.log
        tasks = rfsuite.tasks
        firstWakeup = false
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

    resetFuel()
    resetConsumption()

end

return smart
