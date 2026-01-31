--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = {}
msp.clock = os.clock()

local log
local tasks
local firstWakeup = true

local useRawValue = rfsuite.utils.ethosVersionAtLeast({1, 7, 0})
local lastInFlight = nil
 

--[[
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
 *     on_arm: <boolean>                -- Optional: trigger once when armed edge happens
 *     on_connect: <boolean>            -- Optional: trigger once when link is established
 *     on_disarm: <boolean>             -- Optional: trigger once when disarm edge happens
 *     on_inflight: <boolean>           -- Optional: trigger once when inflight edge happens
 *     on_notinflight: <boolean>        -- Optional: trigger once when leaving inflight
 *
 *     fields = {
 *       field_key = {
 *         sensorname: <string>         -- Label shown in radio telemetry menu
 *         sessionname: <string>        -- Optional session variable name to update
 *         appId: <number>              -- Unique sensor ID (must be unique across all sensors)
 *         unit: <constant>             -- Telemetry unit (e.g., UNIT_RAW, UNIT_VOLT, etc.)
 *         minimum: <number>            -- Optional minimum value (default: -1e9)
 *         maximum: <number>            -- Optional maximum value (default: 1e9)
 *         transform: <function>          -- Optional value processing function before display
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
 * 0x5FFC   - governor mode
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

]]--

-- LuaFormatter off
local msp_sensors = {
    DATAFLASH_SUMMARY = {
        interval_armed = -1,      -- disable periodic polling
        interval_disarmed = -1,   -- disable periodic polling
        on_disarm = true,         -- fire once when disarming  
        on_connect = true,        -- fire once when link is established   
        fields = {
            flags = {
                sensorname = "BBL Flags",
                sessionname = {"bblFlags"},
                appId = 0x5FFF,
                unit = UNIT_RAW
            },
            total = {
                sensorname = "BBL Size",
                sessionname = {"bblSize"},
                appId = 0x5FFE,
                unit = UNIT_RAW
            },
            used = {
                sensorname = "BBL Used",
                sessionname = {"bblUsed"},
                appId = 0x5FFD,
                unit = UNIT_RAW
            }
        }
    },

    BATTERY_CONFIG = {
        interval_armed = -1,
        interval_disarmed = 10,
        fields = {
            voltageMeterSource = {
                sessionname = {"batteryConfig", "voltageMeterSource"}
            },
            batteryCapacity = {
                sessionname = {"batteryConfig", "batteryCapacity"}
            },
            batteryCellCount = {
                sessionname = {"batteryConfig", "batteryCellCount"}
            },
            vbatwarningcellvoltage = {
                sessionname = {"batteryConfig", "vbatwarningcellvoltage"},
                transform = function(v) return v / 100 end
            },
            vbatmincellvoltage = {
                sessionname = {"batteryConfig", "vbatmincellvoltage"},
                transform = function(v) return v / 100 end
            },
            vbatmaxcellvoltage = {
                sessionname = {"batteryConfig", "vbatmaxcellvoltage"},
                transform = function(v) return v / 100 end
            },
            vbatfullcellvoltage = {
                sessionname = {"batteryConfig", "vbatfullcellvoltage"},
                transform = function(v) return v / 100 end
            },
            lvcPercentage = {
                sessionname = {"batteryConfig", "lvcPercentage"}
            },
            consumptionWarningPercentage = {
                sessionname = {"batteryConfig", "consumptionWarningPercentage"}
            }
        }
    },

    NAME = {
        interval_armed = -1,
        interval_disarmed = 30,
        fields = {
            name = {
                sessionname = {"craftName"}
            }
        }
    },


    GOVERNOR_CONFIG = {
        interval_armed = -1,
        interval_disarmed = 10,
        fields = {
            gov_mode ={
                sessionname = {"governorMode"},
                sensorname = "Governor Mode",
                appId = 0x5FFC,
                unit = UNIT_RAW
            }
        }
    }
}
-- LuaFormatter on

msp.sensors = msp_sensors

local sensorCache = {}
local negativeCache = {}
local lastValue = {}
local lastPush = {}
local lastModule = nil

-- Cache loaded MSP API modules so we don't touch disk (loadfile/compile) on periodic polls.
-- Also lets us install handlers/UUID once, instead of reallocating closures every poll.
local apiCache = {}

local VALUE_EPSILON = 0.0
local FORCE_REFRESH_INTERVAL = 2.5

local next_due = {}
local activeFields = {}
local lastState = {
    isArmed = false,
    isAdmin = false,
    isConnected = false
}

local function isInFlightNow()
    return (rfsuite.flightmode and rfsuite.flightmode.current == "inflight") and true or false
end

local function computeInterval(api_meta, isArmed, isAdmin)
    if isAdmin then return -1 end
    if isArmed == 1 or isArmed == 3 then
        return api_meta.interval_armed or 2
    else
        return api_meta.interval_disarmed or 2
    end
end

local function rescheduleAll(isArmed, isAdmin, now)
    for api_name, api_meta in pairs(msp_sensors) do
        local interval = computeInterval(api_meta, isArmed, isAdmin)
        if interval and interval > 0 then
            next_due[api_name] = now
        else
            next_due[api_name] = nil
        end
        api_meta.last_time = api_meta.last_time or 0
    end
end

local function clamp(v, minv, maxv)
    if v == nil then return nil end
    if v < minv then
        return minv
    elseif v > maxv then
        return maxv
    else
        return v
    end
end

local function createOrUpdateSensor(appId, fieldMeta, value)

    local currentModule = rfsuite.session.telemetrySensor and rfsuite.session.telemetrySensor:module()
    if lastModule ~= currentModule then
        sensorCache = {}
        negativeCache = {}
        lastValue = {}
        lastPush = {}
        lastModule = currentModule
    end

    if sensorCache[appId] == nil and negativeCache[appId] then return end

    if not sensorCache[appId] and not negativeCache[appId] then
        local existingSensor = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = appId})
        if existingSensor then
            sensorCache[appId] = existingSensor
        else
            if not (rfsuite.session.telemetryState and rfsuite.session.telemetrySensor) then
                negativeCache[appId] = true
                return
            end
            local sensor = model.createSensor()
            sensor:name(fieldMeta.sensorname)
            sensor:appId(appId)
            sensor:physId(0)
            sensor:module(rfsuite.session.telemetrySensor:module())

            if fieldMeta.unit then
                sensor:unit(fieldMeta.unit)
                sensor:protocolUnit(fieldMeta.unit)
            end
            sensor:minimum(fieldMeta.minimum or -1e9)
            sensor:maximum(fieldMeta.maximum or 1e9)

            sensorCache[appId] = sensor
        end
        if not sensorCache[appId] then negativeCache[appId] = true end
    end

    local sensor = sensorCache[appId]
    if not sensor then return end

    local minv = fieldMeta.minimum or -1e9
    local maxv = fieldMeta.maximum or 1e9
    local v = clamp(value, minv, maxv)
    local last = lastValue[appId]
    local nowc = msp.clock
    local stale = (nowc - (lastPush[appId] or 0)) >= FORCE_REFRESH_INTERVAL

    if v == nil then
        sensor:reset()
        lastValue[appId] = nil
        lastPush[appId] = nowc
        return
    end

    if last == nil or math.abs(v - last) >= VALUE_EPSILON or stale then
        if useRawValue then
            sensor:rawValue(v)
        else
            sensor:value(v)
        end
        lastValue[appId] = v
        lastPush[appId] = nowc
    end
end

local function updateSessionField(meta, value)
    if not meta.sessionname or type(rfsuite.session) ~= "table" then return end
    local t = rfsuite.session

    for i = 1, #meta.sessionname - 1 do
        local k = meta.sessionname[i]
        if type(t[k]) ~= "table" then t[k] = {} end
        t = t[k]
    end

    t[meta.sessionname[#meta.sessionname]] = value
end

local function getApi(api_name, fields)
    local cached = apiCache[api_name]
    if cached then return cached end

    -- First load can be expensive (disk + compile). Keep it around.
    local API = tasks.msp.api.load(api_name)
    apiCache[api_name] = API

    -- Stable UUID per API (set once)
    API.setUUID("uuid-" .. api_name)

    -- Install a stable completion handler (set once)
    API.setCompleteHandler(function(self, buf)
        local now = os.clock()
        msp.clock = now

        for field_key, meta in pairs(fields) do
            local value = API.readValue(field_key)
            if value ~= nil then
                if meta.transform and type(meta.transform) == "function" then value = meta.transform(value) end
                meta.last_sent_value = value
                meta.last_update_time = now

                if meta.sensorname and meta.appId then
                    createOrUpdateSensor(meta.appId, meta, value)
                    activeFields[meta.appId] = meta
                end
                if meta.sessionname then updateSessionField(meta, value) end
            end
        end
    end)

    return API
end

local lastWakeupTime = 0
function msp.wakeup()

    if rfsuite.flightmode and rfsuite.flightmode.current ~= "inflight" then
        if not rfsuite.session.isConnected then return end
        if rfsuite.session.mspBusy then return end
        if rfsuite.tasks and rfsuite.tasks.onconnect and rfsuite.tasks.onconnect.active and rfsuite.tasks.onconnect.active() then return end
    end

    msp.clock = os.clock()

    if firstWakeup then
        log = rfsuite.utils.log
        tasks = rfsuite.tasks
        firstWakeup = false
    end

    if rfsuite.session.apiVersion == nil then
        log("MSP API version not set; skipping MSP sensors", "debug")
        rfsuite.session.resetMSPSensors = true
        return
    end

    if rfsuite.session.resetMSPSensors then
        sensorCache = {}
        negativeCache = {}
        lastValue = {}
        lastPush = {}
        rfsuite.session.resetMSPSensors = false
    end

    if not (rfsuite.session.telemetryState and rfsuite.session.telemetrySensor) then
        sensorCache = {}
        negativeCache = {}
        lastValue = {}
        lastPush = {}
        return
    end

    local now = msp.clock
    lastWakeupTime = now

    if not tasks.msp.mspQueue:isProcessed() then return end

    local armSource = tasks.telemetry.getSensorSource("armflags")
    if not armSource then return end
    local isArmed = armSource:value()
    local isAdmin = rfsuite.app.guiIsRunning

    local isConnected = rfsuite.session.isConnected == true


    local armedBool = (isArmed == 1 or isArmed == 3)
    local inFlight = isInFlightNow()

    -- Edge detection (armed + inflight)
    local prevArmed = lastState.isArmed
    local prevInFlight = lastInFlight
    if prevInFlight == nil then prevInFlight = inFlight end

    local armEdge = (prevArmed == false and armedBool == true)
    local disarmEdge = (prevArmed == true and armedBool == false)
    local inflightEdge = (prevInFlight == false and inFlight == true)
    local notInFlightEdge = (prevInFlight == true and inFlight == false)
    local connectEdge = (lastState.isConnected == false and isConnected == true)

    lastState.isConnected = isConnected

    lastInFlight = inFlight

    local stateChanged = (lastState.isArmed ~= armedBool) or (lastState.isAdmin ~= isAdmin)
    if stateChanged then
        rescheduleAll(isArmed, isAdmin, now)
        lastState.isArmed = armedBool
        lastState.isAdmin = isAdmin
    end

    -- Hook-trigger scheduling (optional per API)
    if armEdge or disarmEdge or inflightEdge or notInFlightEdge or connectEdge then
        for api_name, api_meta in pairs(msp_sensors) do
            if (connectEdge and api_meta.on_connect)
                or (armEdge and api_meta.on_arm)
                or (disarmEdge and api_meta.on_disarm)
                or (inflightEdge and api_meta.on_inflight)
                or (notInFlightEdge and api_meta.on_notinflight) then
                next_due[api_name] = now
            end
        end
    end

    do
        local empty = true
        for _ in pairs(next_due) do
            empty = false
            break
        end
        if empty then rescheduleAll(isArmed, isAdmin, now) end
    end

    for appId, meta in pairs(activeFields) do
        if meta.last_sent_value ~= nil and (now - (lastPush[appId] or 0)) >= FORCE_REFRESH_INTERVAL then
            createOrUpdateSensor(appId, meta, meta.last_sent_value)
            meta.last_update_time = now
            lastPush[appId] = now
        end
    end

    if isAdmin then return end

    for api_name, due in pairs(next_due) do
        if due and now >= due then
            local api_meta = msp_sensors[api_name]
            local interval = computeInterval(api_meta, isArmed, isAdmin)
            if interval and interval > 0 then
                next_due[api_name] = now + interval
            else
                next_due[api_name] = nil
            end

            local fields = api_meta.fields

            -- IMPORTANT: don't (re)load modules or rebuild handlers on every poll.
            local API = getApi(api_name, fields)

            -- Dispatch at most one MSP read per scheduler wakeup to avoid a single frame
            -- taking a large hit when multiple APIs become due at the same time.
            API.read()
            break
        end
    end
end

function msp.reset()

    -- Reset the sensors before clearing caches
    for i,v in pairs(sensorCache) do
        if v then
            v:reset()
        end
    end

    sensorCache = {}
    negativeCache = {}
    lastValue = {}
    lastPush = {}
    lastModule = nil
    next_due = {}
    activeFields = {}
    lastInFlight = nil
    lastState = {
        isArmed = false,
        isAdmin = false,
        isConnected = false
    }

    local now = msp.clock
    for api_name, _ in pairs(msp_sensors) do next_due[api_name] = now end

    for _, api_meta in pairs(msp_sensors) do
        api_meta.last_time = 0
        for _, meta in pairs(api_meta.fields or {}) do
            meta.last_update_time = 0
            meta.last_sent_value = nil
        end
    end
end

return msp
