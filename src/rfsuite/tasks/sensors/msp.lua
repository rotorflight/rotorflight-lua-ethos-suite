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

local msp_sensors = {
    DATAFLASH_SUMMARY = {interval_armed = -1, interval_disarmed = 5, fields = {flags = {sensorname = "BBL Flags", sessionname = {"bblFlags"}, appId = 0x5FFF, unit = UNIT_RAW}, total = {sensorname = "BBL Size", sessionname = {"bblSize"}, appId = 0x5FFE, unit = UNIT_RAW}, used = {sensorname = "BBL Used", sessionname = {"bblUsed"}, appId = 0x5FFD, unit = UNIT_RAW}}},

    BATTERY_CONFIG = {
        interval_armed = -1,
        interval_disarmed = 5,
        fields = {
            voltageMeterSource = {sessionname = {"batteryConfig", "voltageMeterSource"}},
            batteryCapacity = {sessionname = {"batteryConfig", "batteryCapacity"}},
            batteryCellCount = {sessionname = {"batteryConfig", "batteryCellCount"}},
            vbatwarningcellvoltage = {sessionname = {"batteryConfig", "vbatwarningcellvoltage"}, transform = function(v) return v / 100 end},
            vbatmincellvoltage = {sessionname = {"batteryConfig", "vbatmincellvoltage"}, transform = function(v) return v / 100 end},
            vbatmaxcellvoltage = {sessionname = {"batteryConfig", "vbatmaxcellvoltage"}, transform = function(v) return v / 100 end},
            vbatfullcellvoltage = {sessionname = {"batteryConfig", "vbatfullcellvoltage"}, transform = function(v) return v / 100 end},
            lvcPercentage = {sessionname = {"batteryConfig", "lvcPercentage"}},
            consumptionWarningPercentage = {sessionname = {"batteryConfig", "consumptionWarningPercentage"}}
        }
    },

    NAME = {interval_armed = -1, interval_disarmed = 30, fields = {name = {sessionname = {"craftName"}}}}
}

msp.sensors = msp_sensors

local sensorCache = {}
local negativeCache = {}
local lastValue = {}
local lastPush = {}
local lastModule = nil

local VALUE_EPSILON = 0.0
local FORCE_REFRESH_INTERVAL = 2.5

local next_due = {}
local activeFields = {}
local lastState = {isArmed = false, isAdmin = false}

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
        sensor:value(v)
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

    local armedBool = (isArmed == 1 or isArmed == 3)
    local stateChanged = (lastState.isArmed ~= armedBool) or (lastState.isAdmin ~= isAdmin)
    if stateChanged then
        rescheduleAll(isArmed, isAdmin, now)
        lastState.isArmed = armedBool
        lastState.isAdmin = isAdmin
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
            local API = tasks.msp.api.load(api_name)
            API.setCompleteHandler(function(self, buf)
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
            API.setUUID("uuid-" .. api_name)
            API.read()
        end
    end
end

function msp.reset()
    sensorCache = {}
    negativeCache = {}
    lastValue = {}
    lastPush = {}
    lastModule = nil
    next_due = {}
    activeFields = {}

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
