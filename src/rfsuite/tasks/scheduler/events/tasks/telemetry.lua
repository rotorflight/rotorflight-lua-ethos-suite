--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}

local telemetry = {}

local lastEventTimes = {}
local lastValues = {}
local lastAlertState = {}
local rollingSamples = {}
local sensorSources = {}

local batteryConfigCache = {
    config = nil,
    profiles = nil,
    batteryCapacity = 0,
    batteryCellCount = 0,
    vbatwarningcellvoltage = 0,
    vbatmincellvoltage = 0,
    profileSig = 0,
    hasAnyBatteryCapacity = false,
    hasAnyProfileCapacity = false,
    profileCaps = {},
    smartfuelModelType = 0,
    modelPrefs = nil
}

local lastSmartfuelAnnounced = nil
local lastLowFuelAnnounced = false
local lastLowFuelRepeat = 0
local lastLowFuelRepeatCount = 0

-- Shared clock value set once per wakeup; used by all event closures as an upvalue
-- to avoid repeated os.clock() calls inside hot-path event handlers.
local now = 0

local utils = rfsuite.utils
local os_clock = os.clock
local math_floor = math.floor
local math_abs = math.abs
local system_playNumber = system.playNumber
local system_playHaptic = system.playHaptic

local MAX_BATTERY_PROFILES = 6
local PROFILE_HASH_BASE = 131

local armMap = {[0] = "disarmed.wav", [1] = "armed.wav", [2] = "disarmed.wav", [3] = "armed.wav"}
local governorMap = {
    [0] = "off.wav",
    [1] = "idle.wav",
    [2] = "spoolup.wav",
    [3] = "recovery.wav",
    [4] = "active.wav",
    [5] = "thr-off.wav",
    [6] = "lost-hs.wav",
    [7] = "autorot.wav",
    [8] = "bailout.wav",
    [100] = "disabled.wav",
    [101] = "disarmed.wav"
}

local lastSmartfuelSel = nil
local cachedSmartfuelThresholds = nil

local function extractCapacityValue(v)
    if type(v) == "number" then return v end
    if type(v) == "string" then return tonumber(v:match("(%d+)")) end
    if type(v) == "table" then
        if type(v.capacity) == "number" then return v.capacity end
        if type(v.capacity) == "string" then return tonumber(v.capacity:match("(%d+)")) end
        if type(v.name) == "string" then return tonumber(v.name:match("(%d+)")) end
    end
    return nil
end

local function clearProfileCaps(caps)
    for i = 0, MAX_BATTERY_PROFILES - 1 do
        caps[i] = nil
    end
end

local function extractProfileCapacity(profiles, idx)
    if type(profiles) ~= "table" then return nil end
    local v = profiles[idx]
    if v == nil then v = profiles[idx + 1] end
    return extractCapacityValue(v)
end

local function resetBatteryConfigCache()
    batteryConfigCache.config = nil
    batteryConfigCache.profiles = nil
    batteryConfigCache.batteryCapacity = 0
    batteryConfigCache.batteryCellCount = 0
    batteryConfigCache.vbatwarningcellvoltage = 0
    batteryConfigCache.vbatmincellvoltage = 0
    batteryConfigCache.profileSig = 0
    batteryConfigCache.hasAnyBatteryCapacity = false
    batteryConfigCache.hasAnyProfileCapacity = false
    batteryConfigCache.smartfuelModelType = 0
    batteryConfigCache.modelPrefs = nil
    clearProfileCaps(batteryConfigCache.profileCaps)
end

local function buildProfileSignature(profiles)
    local profileSig = 0
    for i = 0, MAX_BATTERY_PROFILES - 1 do
        local cap = extractProfileCapacity(profiles, i)
        profileSig = profileSig * PROFILE_HASH_BASE + (math_floor((cap or -1) + 0.5) + 1)
    end
    return profileSig
end

local function rebuildProfileCaps(profiles, profileCaps)
    local hasProfileCapacity = false
    clearProfileCaps(profileCaps)

    for i = 0, MAX_BATTERY_PROFILES - 1 do
        local cap = extractProfileCapacity(profiles, i)
        if cap and cap > 0 then
            hasProfileCapacity = true
            profileCaps[i] = cap
        end
    end

    return hasProfileCapacity
end

local function resetLowFuelState()
    lastLowFuelAnnounced = false
    lastLowFuelRepeat = 0
    lastLowFuelRepeatCount = 0
end

local function refreshBatteryConfigCache()
    local session = rfsuite.session
    local bc = session and session.batteryConfig

    if not bc then
        resetBatteryConfigCache()
        return nil
    end

    local profiles = bc.profiles
    local batteryCapacity = tonumber(bc.batteryCapacity) or 0
    local batteryCellCount = tonumber(bc.batteryCellCount) or 0
    local vbatwarningcellvoltage = tonumber(bc.vbatwarningcellvoltage) or 0
    local vbatmincellvoltage = tonumber(bc.vbatmincellvoltage) or 0
        local profileSig = buildProfileSignature(profiles)

    if batteryConfigCache.config == bc and
        batteryConfigCache.profiles == profiles and
        batteryConfigCache.batteryCapacity == batteryCapacity and
        batteryConfigCache.batteryCellCount == batteryCellCount and
        batteryConfigCache.vbatwarningcellvoltage == vbatwarningcellvoltage and
        batteryConfigCache.vbatmincellvoltage == vbatmincellvoltage and
        batteryConfigCache.profileSig == profileSig then
        return batteryConfigCache
    end

    batteryConfigCache.config = bc
    batteryConfigCache.profiles = profiles
    batteryConfigCache.batteryCapacity = batteryCapacity
    batteryConfigCache.batteryCellCount = batteryCellCount
    batteryConfigCache.vbatwarningcellvoltage = vbatwarningcellvoltage
    batteryConfigCache.vbatmincellvoltage = vbatmincellvoltage
    batteryConfigCache.profileSig = profileSig

    local profileCaps = batteryConfigCache.profileCaps
    local hasProfileCapacity = rebuildProfileCaps(profiles, profileCaps)

    batteryConfigCache.hasAnyProfileCapacity = hasProfileCapacity
    batteryConfigCache.hasAnyBatteryCapacity = (batteryCapacity > 0) or hasProfileCapacity

    local modelPrefs = (session.modelPreferences and session.modelPreferences.battery) or {}
    batteryConfigCache.modelPrefs = modelPrefs
    batteryConfigCache.smartfuelModelType = tonumber(modelPrefs.smartfuel_model_type) or 0

    return batteryConfigCache
end

local function smartfuelIsElectricModel()
    local bcCache = refreshBatteryConfigCache()
    if not bcCache then return false end

    local cellCount = bcCache.batteryCellCount
    if cellCount ~= 0 then return true end

    return bcCache.hasAnyBatteryCapacity
end

-- Returns callout and empty audio in one call, calling smartfuelIsElectricModel only once.
local function resolveSmartfuelAudio()
    local isElectric = smartfuelIsElectricModel()
    local modelType = batteryConfigCache.smartfuelModelType

    local useBatteryCallout
    if modelType == 0 then
        useBatteryCallout = isElectric
    elseif modelType == 1 then
        useBatteryCallout = true
    else
        useBatteryCallout = false
    end

    local calloutPkg, calloutFile
    if useBatteryCallout then
        calloutPkg, calloutFile = "events", "alerts/battery.wav"
    else
        calloutPkg, calloutFile = "status", "alerts/fuel.wav"
    end

    local emptyPkg, emptyFile
    if isElectric then
        emptyPkg, emptyFile = "status", "alerts/batteryempty.wav"
    else
        emptyPkg, emptyFile = "status", "alerts/lowfuel.wav"
    end

    return calloutPkg, calloutFile, emptyPkg, emptyFile
end

local function resolveBatteryCapacity(typeIndex)
    local bcCache = refreshBatteryConfigCache()
    if not bcCache then return nil end
    return bcCache.profileCaps[typeIndex]
end

local function buildSmartfuelThresholds(sel)
    if sel == lastSmartfuelSel and cachedSmartfuelThresholds then return cachedSmartfuelThresholds end

    local t
    if sel == 0 then
        t = {100, 10}
    elseif sel == 10 then
        t = {}
        for i = 100, 10, -10 do t[#t + 1] = i end
    elseif sel == 20 then
        t = {}
        for i = 100, 20, -20 do t[#t + 1] = i end
        t[#t + 1] = 10
    elseif sel == 25 then
        t = {100, 75, 50, 25, 10}
    elseif sel == 50 then
        t = {100, 50, 10}
    elseif sel == 5 then
        t = {50, 5}
    elseif type(sel) == "number" and sel > 0 then
        t = {sel}
    else
        t = {10}
    end
    lastSmartfuelSel = sel
    cachedSmartfuelThresholds = t
    return t
end

local function smartfuelCallout(value, now)
    local eventPrefs = rfsuite.preferences.events or {}
    local smartfuelcallout = tonumber(eventPrefs.smartfuelcallout) or 0
    local thresholds = buildSmartfuelThresholds(smartfuelcallout)
    local calloutPkg, calloutFile, emptyPkg, emptyFile = resolveSmartfuelAudio()

    if value <= 0 then
        local repeats = tonumber(eventPrefs.smartfuelrepeats) or 1
        local haptic = eventPrefs.smartfuelhaptic and true or false

        if not lastLowFuelAnnounced then
            utils.playFile(emptyPkg, emptyFile)
            if haptic then system_playHaptic(". . . .") end
            lastLowFuelRepeat = now
            lastLowFuelRepeatCount = 1
            lastLowFuelAnnounced = true
        elseif lastLowFuelRepeatCount < repeats and (now - lastLowFuelRepeat) >= 10 then
            utils.playFile(emptyPkg, emptyFile)
            if haptic then system_playHaptic(". . . .") end
            lastLowFuelRepeat = now
            lastLowFuelRepeatCount = lastLowFuelRepeatCount + 1
        end
        return
    else
        resetLowFuelState()
    end

    if lastSmartfuelAnnounced == nil then
        utils.playFile(calloutPkg, calloutFile)
        system_playNumber(math_floor(value + 0.5), UNIT_PERCENT)
        lastSmartfuelAnnounced = math_floor(value + 0.5)
        return
    end

    local calloutValue = nil

    for _, t in ipairs(thresholds) do
        if value <= t and lastSmartfuelAnnounced > t then
            calloutValue = t
            break
        end
    end

    if calloutValue then
        utils.playFile(calloutPkg, calloutFile)
        system_playNumber(calloutValue, UNIT_PERCENT)
        lastSmartfuelAnnounced = calloutValue
    end
end

local function shouldAlert(key, interval, now)
    return (not lastAlertState[key]) or (now - (lastEventTimes[key] or 0)) >= interval
end

local function registerAlert(key, now)
    lastEventTimes[key] = now
    lastAlertState[key] = true
end

local function updateRollingAverage(key, newValue, window)
    local state = rollingSamples[key]
    if not state or state.window ~= window then
        state = {buf = {}, next = 1, count = 0, sum = 0, window = window}
        rollingSamples[key] = state
    end

    local idx = state.next
    if state.count == window then
        state.sum = state.sum - (state.buf[idx] or 0)
    else
        state.count = state.count + 1
    end

    state.buf[idx] = newValue
    state.sum = state.sum + newValue

    idx = idx + 1
    if idx > window then idx = 1 end
    state.next = idx

    return state.sum / state.count
end

local eventTable = {
    {
        sensor = "armflags",
        event = function(value)
            local key = "armflags"
            if value == lastValues[key] then return end
            local filename = armMap[math_floor(value)]
            if filename then utils.playFile("events", "alerts/" .. filename) end
        end
    }, {
        sensor = "voltage",
        interval = 10,
        window = 5,
        event = function(value, interval, window)
            local session = rfsuite.session
            local bcCache = batteryConfigCache
            if not bcCache.config then return end

            local cellCount = bcCache.batteryCellCount
            local warnVoltage = bcCache.vbatwarningcellvoltage
            local minVoltage = bcCache.vbatmincellvoltage
            if cellCount <= 0 then return end

            local cellVoltage = value / cellCount
            if cellVoltage < (minVoltage / 2) then return end

            local avgVoltage = updateRollingAverage("voltage", cellVoltage, window)

            local collective = session.rx.values['collective'] or 0
            local aileron = session.rx.values['aileron'] or 0
            local elevator = session.rx.values['elevator'] or 0
            local rudder = session.rx.values['rudder'] or 0

            local suppression = (rfsuite.preferences.general.gimbalsupression or 0.95) * 1024
            if math_abs(collective) > suppression or math_abs(aileron) > suppression or math_abs(elevator) > suppression or math_abs(rudder) > suppression then return end

            local key = "voltage"
            if avgVoltage < warnVoltage and shouldAlert(key, interval, now) then
                utils.playFile("events", "alerts/lowvoltage.wav")
                registerAlert(key, now)
            elseif avgVoltage >= warnVoltage then
                lastAlertState[key] = false
            end
        end
    }, {
        sensor = "temp_esc",
        interval = 10,
        window = 5,
        event = function(value, interval, window)
            local eventPrefs = rfsuite.preferences.events or {}
            if not eventPrefs.temp_esc then return end
            local escalertvalue = tonumber(eventPrefs.escalertvalue) or 90
            local avgTemp = updateRollingAverage("temp_esc", value, window)
            local key = "temp_esc"
            if avgTemp >= escalertvalue and shouldAlert(key, interval, now) then
                utils.playFile("events", "alerts/esctemp.wav")
                system_playHaptic(". . . .")
                registerAlert(key, now)
            elseif avgTemp < escalertvalue then
                lastAlertState[key] = false
            end
        end
    }, {
        sensor = "bec_voltage",
        interval = 10,
        window = 5,
        event = function(value, interval, window)
            if rfsuite.flightmode.current ~= "inflight" then
                lastAlertState["bec_voltage"] = false
                return
            end

            local bcCache = batteryConfigCache
            local batprefs = bcCache.modelPrefs or {}
            local alert_type = tonumber(batprefs.alert_type or 0)
            local becalertvalue = tonumber(batprefs.becalertvalue or 6.5)
            local rxalertvalue = tonumber(batprefs.rxalertvalue or 7.4)
            local avgBEC = updateRollingAverage("bec_voltage", value, window)
            local key = "bec_voltage"

            if alert_type == 1 then
                if avgBEC < becalertvalue and shouldAlert(key, interval, now) then
                    utils.playFile("events", "alerts/becvolt.wav")
                    system_playHaptic(". . . .")
                    registerAlert(key, now)
                elseif avgBEC >= becalertvalue then
                    lastAlertState[key] = false
                end
            elseif alert_type == 2 then
                if avgBEC < rxalertvalue and shouldAlert(key, interval, now) then
                    utils.playFile("events", "alerts/rxvolt.wav")
                    system_playHaptic(". . . .")
                    registerAlert(key, now)
                elseif avgBEC >= rxalertvalue then
                    lastAlertState[key] = false
                end
            else
                lastAlertState[key] = false
            end
        end
    }, {sensor = "smartfuel", event = function(value) smartfuelCallout(value, now) end}, {
        sensor = "governor",
        event = function(value)
            local key = "governor"
            if value == lastValues[key] then return end
            local session = rfsuite.session
            if not session.isArmed or session.governorMode == 0 then return end
            local filename = governorMap[math_floor(value)]
            if filename then utils.playFile("events", "gov/" .. filename) end
        end
    }, {
        sensor = "pid_profile",
        debounce = 0.25,
        event = function(value)
            local key = "pid_profile"
            if value == lastValues[key] then return end
            utils.playFile("events", "alerts/profile.wav")
            system_playNumber(math_floor(value))
        end
    }, {
        sensor = "rate_profile",
        debounce = 0.25,
        event = function(value)
            local key = "rate_profile"
            if value == lastValues[key] then return end
            utils.playFile("events", "alerts/rates.wav")
            system_playNumber(math_floor(value))
        end
    }, {
        sensor = "battery_profile",
        debounce = 0.25,
        event = function(value)
            local key = "battery_profile"
            if value == lastValues[key] then return end
            local bcCache = batteryConfigCache
            if not bcCache.config or not bcCache.hasAnyProfileCapacity then return end
            utils.playFile("events", "alerts/battery.wav")
            local cap = resolveBatteryCapacity(math_floor(value) - 1)
            if cap and system_playNumber then
                system_playNumber(math_floor(cap + 0.5), UNIT_MILLIAMPERE_HOUR)
            end
        end
    }
}

function telemetry.wakeup()

    -- we need governor mode for some events
    if rfsuite.session.governorMode == nil then
        if rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.helpers then
            rfsuite.tasks.msp.helpers.governorMode(function(governorMode)
                utils.log("Telemetry event Received governor mode: " .. tostring(governorMode), "info")
            end)
        end
    end

    now = os_clock()
    local eventPrefs = rfsuite.preferences.events or {}
    local tlmTask = rfsuite.tasks.telemetry

    refreshBatteryConfigCache()

    for _, item in ipairs(eventTable) do
        local key = item.sensor
        local interval = item.interval or 0
        local debounce = item.debounce or 0
        local lastTime = lastEventTimes[key] or (now - interval)
        local lastVal = lastValues[key]

        if not eventPrefs[key] then goto continue end

        local source = sensorSources[key]
        if not source then
            if tlmTask then
                source = tlmTask.getSensorSource(key)
                if source then sensorSources[key] = source end
            end
        end
        if not source then goto continue end

        local value = source:value()
        if value == nil then goto continue end

        if interval > 0 then
            item.event(value, interval, item.window or 1)
        elseif (not lastVal or value ~= lastVal) or debounce == 0 or (now - lastTime) >= debounce then
            item.event(value, interval, item.window or 1)
            lastEventTimes[key] = now
        end

        lastValues[key] = value
        ::continue::
    end
end

telemetry.eventTable = eventTable

function telemetry.reset()
    lastSmartfuelAnnounced = nil
    resetLowFuelState()
    lastEventTimes = {}
    lastValues = {}
    lastAlertState = {}
    rollingSamples = {}
    sensorSources = {}
    resetBatteryConfigCache()
end

return telemetry
