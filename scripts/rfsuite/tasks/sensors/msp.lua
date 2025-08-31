--[[

 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html

 * MSP Sensor Table Structure
 *
 * `msp_sensors` defines which MSP APIs to poll and how to map their values
 * into telemetry sensors for the radio.
 *
 * Each top-level key is the MSP API name (e.g., "DATAFLASH_SUMMARY").
 * Each entry defines:
 *
 *   - Polling intervals (armed/disarmed)
 *   - A `fields` table of telemetry sensor definitions
 *
 * Structure:
 * {
 *   API_NAME = {
 *     interval_armed    = <number>,   -- Poll interval in seconds when armed (-1 = no polling)
 *     interval_disarmed = <number>,   -- Poll interval when disarmed (-1 = no polling)
 *
 *     fields = {
 *       field_key = {
 *         sensorname   = <string>,    -- Label in radio telemetry menu
 *         sessionname  = <string[]>,  -- Optional session variable path
 *         appId        = <number>,    -- Unique sensor ID (must be unique globally)
 *         unit         = <constant>,  -- Telemetry unit (UNIT_RAW, UNIT_VOLT, etc.)
 *         minimum      = <number>,    -- Optional min value (default: -1e9)
 *         maximum      = <number>,    -- Optional max value (default:  1e9)
 *         transform    = <function>,  -- Optional transform before display
 *       },
 *       ...
 *     }
 *   },
 *   ...
 * }
 *
 * Reserved sensor IDs:
 *   0x5FFF   - bbl flags
 *   0x5FFE   - bbl size
 *   0x5FFD   - bbl used
 *   0x5FFC
 *   0x5FFB
 *   0x5FFA
 *   0x5FF9
 *   0x5FF8
 *   0x5FF7
 *   0x5FF6
 *   0x5FF5
 *   0x5FF4
 *   0x5FF3
 *   0x5FF2
 *   0x5FF1
 *   0x5FF0
 *   0x5FEF
 *   0x5FEE
 *   0x5FED
 *   0x5FEC
 *   0x5FEB
 *   0x5FEA
 *   0x5FE9
 *   0x5FE8
 *   0x5FE7
 *   0x5FE6
 *   0x5FE5
 *   0x5FE4
 *   0x5FE3
 *   0x5FE2
 *
]]

local msp = {}
msp.clock = os.clock()

-- Container variables
local log
local tasks 
local firstWakeup = true

-- MSP → Telemetry Sensor mapping
local msp_sensors = {
    DATAFLASH_SUMMARY = {
        interval_armed    = -1,
        interval_disarmed = 5,
        fields = {
            flags = {
                sensorname  = "BBL Flags",
                sessionname = { "bblFlags" },
                appId       = 0x5FFF,
                unit        = UNIT_RAW,
            },
            total = {
                sensorname  = "BBL Size",
                sessionname = { "bblSize" },
                appId       = 0x5FFE,
                unit        = UNIT_RAW,
            },
            used = {
                sensorname  = "BBL Used",
                sessionname = { "bblUsed" },
                appId       = 0x5FFD,
                unit        = UNIT_RAW,
            },         
        },
    },

    BATTERY_CONFIG = {
        interval_armed    = -1,
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
                transform   = function(v) return v / 100 end,
            },
            vbatmincellvoltage = {
                sessionname = { "batteryConfig", "vbatmincellvoltage" },
                transform   = function(v) return v / 100 end,
            },
            vbatmaxcellvoltage = {
                sessionname = { "batteryConfig", "vbatmaxcellvoltage" },
                transform   = function(v) return v / 100 end,
            },
            vbatfullcellvoltage = {
                sessionname = { "batteryConfig", "vbatfullcellvoltage" },
                transform   = function(v) return v / 100 end,
            },
            lvcPercentage = {
                sessionname = { "batteryConfig", "lvcPercentage" },
            },
            consumptionWarningPercentage = {
                sessionname = { "batteryConfig", "consumptionWarningPercentage" },
            },
        },        
    }, 

    NAME = {
        interval_armed    = -1,
        interval_disarmed = 30,
        fields = {
            name = {
                sessionname = { "craftName" },
            },        
        },
    },             
}

msp.sensors = msp_sensors

-- Caches
local sensorCache   = {}
local negativeCache = {}  -- appId -> true if system.getSource() returned nil
local lastValue     = {}  -- appId -> last value pushed
local lastPush      = {}  -- appId -> last os.clock() push time
local lastModule    = nil

-- Constants
local VALUE_EPSILON          = 0.0  -- push on any change (set >0 to throttle)
local FORCE_REFRESH_INTERVAL = 2.5    -- seconds; heartbeat refresh interval

-- Scheduler state
local next_due     = {}  -- api_name -> epoch seconds for next poll
local activeFields = {}  -- appId -> field meta (for heartbeat)
local lastState    = { isArmed = false, isAdmin = false }

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------

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
            next_due[api_name] = now -- Run immediately; could add jitter here
        else
            next_due[api_name] = nil
        end
        api_meta.last_time = api_meta.last_time or 0
    end
end

local function clamp(v, minv, maxv)
    if v == nil then return nil end
    if v < minv then return minv
    elseif v > maxv then return maxv
    else return v end
end

local function createOrUpdateSensor(appId, fieldMeta, value)
    -- Detect module changes and invalidate caches
    local currentModule = rfsuite.session.telemetrySensor
                        and rfsuite.session.telemetrySensor:module()
    if lastModule ~= currentModule then
        sensorCache   = {}
        negativeCache = {}
        lastValue     = {}
        lastPush      = {}
        lastModule    = currentModule
    end

    -- Skip repeated lookups if no source
    if sensorCache[appId] == nil and negativeCache[appId] then
        return -- wait for reset
    end

    -- Try to bind sensor
    if not sensorCache[appId] and not negativeCache[appId] then
        local existingSensor = system.getSource({
            category = CATEGORY_TELEMETRY_SENSOR,
            appId    = appId
        })
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
            sensor:maximum(fieldMeta.maximum or  1e9)

            sensorCache[appId] = sensor
        end
        if not sensorCache[appId] then negativeCache[appId] = true end
    end

    local sensor = sensorCache[appId]
    if not sensor then return end

    -- Clamp & push (with heartbeat)
    local minv  = fieldMeta.minimum or -1e9
    local maxv  = fieldMeta.maximum or  1e9
    local v     = clamp(value, minv, maxv)
    local last  = lastValue[appId]
    local nowc  = msp.clock
    local stale = (nowc - (lastPush[appId] or 0)) >= FORCE_REFRESH_INTERVAL

    if v == nil then
        sensor:reset()
        lastValue[appId] = nil
        lastPush[appId]  = nowc
        return
    end

    if last == nil or math.abs(v - last) >= VALUE_EPSILON or stale then
        sensor:value(v)
        lastValue[appId] = v
        lastPush[appId]  = nowc
    end
end

local function updateSessionField(meta, value)
    if not meta.sessionname or type(rfsuite.session) ~= "table" then return end
    local t = rfsuite.session
    -- Walk all but the last key
    for i = 1, #meta.sessionname - 1 do
        local k = meta.sessionname[i]
        if type(t[k]) ~= "table" then t[k] = {} end
        t = t[k]
    end
    -- Set the leaf
    t[meta.sessionname[#meta.sessionname]] = value
end

----------------------------------------------------------------------
-- Main Wakeup Loop
----------------------------------------------------------------------

local lastWakeupTime = 0
function msp.wakeup()
    msp.clock = os.clock()

    if firstWakeup then
        log   = rfsuite.utils.log
        tasks = rfsuite.tasks
        firstWakeup = false
    end

    if rfsuite.session.apiVersion == nil then
        log("MSP API version not set; skipping MSP sensors", "debug")
        rfsuite.session.resetMSPSensors = true
        return
    end

    if rfsuite.session.resetMSPSensors then
        sensorCache   = {}
        negativeCache = {}
        lastValue     = {}
        lastPush      = {}
        rfsuite.session.resetMSPSensors = false
    end

    -- Bail if telemetry inactive
    if not (rfsuite.session.telemetryState and rfsuite.session.telemetrySensor) then
        sensorCache   = {}
        negativeCache = {}
        lastValue     = {}
        lastPush      = {}
        return
    end

    local now = msp.clock
    lastWakeupTime = now

    if not tasks.msp.mspQueue:isProcessed() then
        log("MSP queue busy.. skipping dynamic MSP sensors", "info")
        return
    end

    local armSource = tasks.telemetry.getSensorSource("armflags")
    if not armSource then return end
    local isArmed = armSource:value()
    local isAdmin = rfsuite.app.guiIsRunning

    if isAdmin then return end -- Pause polling when GUI open

    -- Reschedule if state changed
    local armedBool    = (isArmed == 1 or isArmed == 3)
    local stateChanged = (lastState.isArmed ~= armedBool)
                      or (lastState.isAdmin ~= isAdmin)
    if stateChanged then
        rescheduleAll(isArmed, isAdmin, now)
        lastState.isArmed = armedBool
        lastState.isAdmin = isAdmin
    end

    -- Ensure schedule exists
    do
        local empty = true
        for _ in pairs(next_due) do empty = false break end
        if empty then rescheduleAll(isArmed, isAdmin, now) end
    end

    -- Heartbeats
    for appId, meta in pairs(activeFields) do
        if meta.last_sent_value ~= nil
        and (now - (lastPush[appId] or 0)) >= FORCE_REFRESH_INTERVAL then
            createOrUpdateSensor(appId, meta, meta.last_sent_value)
            meta.last_update_time = now
            lastPush[appId] = now
        end
    end

    -- Poll due APIs
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
            local API = tasks.msp.api.load(api_name)
            API.setCompleteHandler(function(self, buf)
                for field_key, meta in pairs(fields) do
                    local value = API.readValue(field_key)
                    if value ~= nil then
                        if meta.transform and type(meta.transform) == "function" then
                            value = meta.transform(value)
                        end
                        meta.last_sent_value  = value
                        meta.last_update_time = now

                        if meta.sensorname and meta.appId then
                            createOrUpdateSensor(meta.appId, meta, value)
                            activeFields[meta.appId] = meta
                        end
                        if meta.sessionname then
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

----------------------------------------------------------------------
-- Reset
----------------------------------------------------------------------

function msp.reset()
    sensorCache   = {}
    negativeCache = {}
    lastValue     = {}
    lastPush      = {}
    lastModule    = nil
    next_due      = {}
    activeFields  = {}

    -- Prime schedule
    local now = msp.clock
    for api_name, _ in pairs(msp_sensors) do
        next_due[api_name] = now
    end

    -- Clear per-field caches
    for _, api_meta in pairs(msp_sensors) do
        api_meta.last_time = 0
        for _, meta in pairs(api_meta.fields or {}) do
            meta.last_update_time = 0
            meta.last_sent_value  = nil
        end
    end
end

return msp
