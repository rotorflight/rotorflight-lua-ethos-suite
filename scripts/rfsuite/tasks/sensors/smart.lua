--[[

 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html

 * MSP Sensor Table Structure
 *
 * smart_sensors: A table defining APIs to be polled via MSP and how to map their values to telemetry sensors.
 * Each top-level key is the MSP API name (e.g., "DATAFLASH_SUMMARY").
 * Each entry must include polling intervals and a 'fields' table containing telemetry sensor configs.
 *
 * Structure:
 * {
 *   API_NAME = {
 *     interval_armed: <number>         -- Interval (in seconds) to poll this API when the model is armed (-1 for no polling)
 *     interval_disarmed: <number>      -- Interval (in seconds) when disarmed (-1 for no polling)
 *
 *     fields = {
 *       field_key = {
 *         sensorname: <string>         -- Label shown in radio telemetry menu
 *         sessionname: <string>        -- Optional session variable name to update
 *         appId: <number>              -- Unique sensor ID (must be unique across all sensors)
 *         unit: <constant>             -- Telemetry unit (e.g., UNIT_RAW, UNIT_VOLT, etc.)
 *         minimum: <number>            -- Optional minimum value (default: -1e9)
 *         maximum: <number>            -- Optional maximum value (default: 1e9)
 *         transform: <function>        -- Optional value processing function before display
 *       },
 *       ...
 *     }
 *   },
 *   ...
 * }

 * Possible sensor ids we can use are.
 * 0x5FE1   - smartfuel
 * 0x5FE0
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

local function resetFuel()
    smartfuel.reset()
    smartfuelvoltage.reset()
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

end

return smart
