--[[

 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html

 * MSP Sensor Table Structure
 *
 * msp_sensors: A table defining APIs to be polled via MSP and how to map their values to telemetry sensors.
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
 * 0x5FFF   - bbl flags
 * 0x5FFE   - bbl size
 * 0x5FFD   - bbl used
 * 0x5FFC
 * 0x5FFB
 * 0x5FFA
 * 0x5FF9
 * 0x5FF8
 * 0x5FF7
 * 0x5FF6
 * 0x5FF5
 * 0x5FF4
 * 0x5FF3
 * 0x5FF2
 * 0x5FF1
 * 0x5FF0
 * 0x5FEF
 * 0x5FEE
 * 0x5FED
 * 0x5FEC
 * 0x5FEB
 * 0x5FEA
 * 0x5FE9
 * 0x5FE8
 * 0x5FE7
 * 0x5FE6
 * 0x5FE5
 * 0x5FE4
 * 0x5FE3
 * 0x5FE2

]]

local msp = {}

-- container vars
local log
local tasks 

local firstWakeup = true

local msp_sensors = {
    DATAFLASH_SUMMARY = {
        interval_armed = -1,
        interval_disarmed = 5,
        fields = {
            flags = {
                sensorname = "BBL Flags",
                sessionname = {"bblFlags"},
                appId = 0x5FFF,
                unit = UNIT_RAW,
            },
            total = {
                sensorname = "BBL Size",
                sessionname = {"bblSize"},
                appId = 0x5FFE,
                unit = UNIT_RAW,
            },
            used = {
                sensorname = "BBL Used",
                sessionname = {"bblUsed"},
                appId = 0x5FFD,
                unit = UNIT_RAW,
            },         
        }
    },
    BATTERY_CONFIG = {
        interval_armed = -1,
        interval_disarmed = 5,
        fields = {
            batteryCapacity = {
                sessionname = { "batteryConfig", "batteryCapacity" },
            },
            batteryCellCount = {
                sessionname = { "batteryConfig", "batteryCellCount" },
            },
            vbatwarningcellvoltage = {
                sessionname = { "batteryConfig", "vbatwarningcellvoltage" },
                transform     = function(v) return v / 100 end,
            },
            vbatmincellvoltage = {
                sessionname = { "batteryConfig", "vbatmincellvoltage" },
                transform     = function(v) return v / 100 end,
            },
            vbatmaxcellvoltage = {
                sessionname = { "batteryConfig", "vbatmaxcellvoltage" },
                transform     = function(v) return v / 100 end,
            },
            vbatfullcellvoltage = {
                sessionname = { "batteryConfig", "vbatfullcellvoltage" },
                transform     = function(v) return v / 100 end,
            },
            lvcPercentage = {
                sessionname = { "batteryConfig", "lvcPercentage" },
            },
            consumptionWarningPercentage = {
                sessionname = { "batteryConfig", "consumptionWarningPercentage" },
            },
        }        
    },          
}

msp.sensors = msp_sensors
local sensorCache = {}

local function getCurrentTime()
    return os.time()
end

local function createOrUpdateSensor(appId, fieldMeta, value)
    if not sensorCache[appId] then
        local existingSensor = system.getSource({ category = CATEGORY_TELEMETRY_SENSOR, appId = appId })

        if existingSensor then
            sensorCache[appId] = existingSensor
        else
            local sensor = model.createSensor()
            sensor:name(fieldMeta.sensorname)
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

    if sensorCache[appId] then
        sensorCache[appId]:value(value)
    end
end

local function updateSessionField(meta, value)
  if not meta.sessionname or type(rfsuite.session) ~= "table" then
    return
  end

  local t = rfsuite.session
  -- walk all but the last key
  for i = 1, #meta.sessionname - 1 do
    local k = meta.sessionname[i]
    if type(t[k]) ~= "table" then
      t[k] = {}
    end
    t = t[k]
  end

  -- set the leaf
  t[meta.sessionname[#meta.sessionname]] = value
end


local lastWakeupTime = 0
function msp.wakeup()

    if firstWakeup then
        log = rfsuite.utils.log
        tasks = rfsuite.tasks
        firstWakeup = false
    end


    if rfsuite.session.apiVersion == nil then
        log("MSP API version not set; skipping MSP sensors", "debug")
        rfsuite.session.resetMSPSensors = true  -- Reset on next wakeup
        return
    end

    if rfsuite.session.resetMSPSensors == true  then
        sensorCache = {}
        rfsuite.session.resetMSPSensors = false  -- Reset immediately
    end

    local now = getCurrentTime()
    if (now - lastWakeupTime) < 2 then return end
    lastWakeupTime = now

    if not tasks.msp.mspQueue:isProcessed() then
        log("MSP queue busy.. skipping dynamic msp sensors", "info")
        return
    end

    local armSource = tasks.telemetry.getSensorSource("armflags")
    if not armSource then return end
    local isArmed = armSource:value()
    local isAdmin = rfsuite.app.guiIsRunning

    for api_name, api_meta in pairs(msp_sensors) do
        api_meta.last_time = api_meta.last_time or 0

        local interval
        if isAdmin then
            interval = -1  -- Admin module loaded, no polling
        elseif isArmed == 1 or isArmed == 3 then
            interval = api_meta.interval_armed or 2
        else
            interval = api_meta.interval_disarmed or 2
        end

        local fields = api_meta.fields
        for _, meta in pairs(fields) do
            meta.last_update_time = meta.last_update_time or 0
            meta.last_sent_value = meta.last_sent_value or nil

            -- Refresh the telemetry sensor every 5s with cached value
            if meta.appId and meta.last_sent_value ~= nil and (now - meta.last_update_time) >= 5 then
                createOrUpdateSensor(meta.appId, meta, meta.last_sent_value)
                meta.last_update_time = now
            end
        end

        if interval > 0 and (now - api_meta.last_time) >= interval then
            api_meta.last_time = now

            --log("MSP API: " .. api_name .. " interval: " .. interval, "info")

            local API = tasks.msp.api.load(api_name)
            API.setCompleteHandler(function(self, buf)
                for field_key, meta in pairs(fields) do
                    local value = API.readValue(field_key)
                    if value ~= nil then
                        meta.last_sent_value = value
                        meta.last_update_time = now

                        -- apply transformation if defined
                        if meta.transform and type(meta.transform) == "function" then
                            value = meta.transform(value)
                        end

                        -- update sensor
                        if meta.sensorname and meta.appId then
                            createOrUpdateSensor(meta.appId, meta, value)
                        end

                        -- update session variable
                        if meta.sessionname  then
                            updateSessionField(meta, value)
                        end

                    end
                end
            end)

            API.setUUID("uuid-" .. api_name)
            API.read()
        end
    end
end

function msp.reset()
    sensorCache = {}
end

return msp
