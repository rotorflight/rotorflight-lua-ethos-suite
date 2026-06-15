--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local enableWakeup = false

local apidata = nil
local config = {}
local triggerSave = false
local configLoaded = false
local configLoading = false
local configApplied = false
local setDefaultSensors = false
local PREV_STATE = {}
local SAVED_CONFIG = {}
local saveDirtyOverride = false
local pendingSaveStateRefresh = 0
local FEATURE_ENABLED_BITMAP = nil
local telemetryBuffer = {}
local lastSessionRef = nil
local lastLinkReady = false
local lifecycleEpoch = 0
local activeApiRefs = setmetatable({}, {__mode = "v"})
local activeApiRefSeq = 0
local NOOP_HANDLER = function() end
local TELEMETRY_PENDING_UUIDS = {
    ["d2a1c5b3-8f4a-3c8e-9d2a-3b6f8e2d9a1c"] = true, -- FEATURE_CONFIG read
    ["a23e4567-e89b-12d3-a456-426614174001"] = true, -- TELEMETRY_CONFIG read
    ["enable-telemetry-feature"] = true, -- FEATURE_CONFIG write
    ["123e4567-e89b-12d3-a456-426614174120"] = true -- TELEMETRY_CONFIG write
}

local STATIC_CACHE_HOST = rfsuite.app or rfsuite
local TELEMETRY_STATIC_CACHE = STATIC_CACHE_HOST and STATIC_CACHE_HOST._telemetryStaticCache or nil

if not TELEMETRY_STATIC_CACHE then
    local sensorList = {
        [1] = {name = "@i18n(telemetry.sensor_heartbeat)@", group = "system"},
        [3] = {name = "@i18n(telemetry.sensor_voltage)@", group = "battery"},
        [4] = {name = "@i18n(telemetry.sensor_current)@", group = "battery"},
        [5] = {name = "@i18n(telemetry.sensor_consumption)@", group = "battery"},
        [6] = {name = "@i18n(telemetry.sensor_charge_level)@", group = "battery"},
        [7] = {name = "@i18n(telemetry.sensor_cell_count)@", group = "battery"},
        [8] = {name = "@i18n(telemetry.sensor_cell_voltage)@", group = "battery"},
        [9] = {name = "@i18n(telemetry.sensor_cell_voltages)@", group = "battery"},
        [10] = {name = "@i18n(telemetry.sensor_ctrl)@", group = "control"},
        [11] = {name = "@i18n(telemetry.sensor_pitch_control)@", group = "control"},
        [12] = {name = "@i18n(telemetry.sensor_roll_control)@", group = "control"},
        [13] = {name = "@i18n(telemetry.sensor_yaw_control)@", group = "control"},
        [14] = {name = "@i18n(telemetry.sensor_coll_control)@", group = "control"},
        [15] = {name = "@i18n(telemetry.sensor_throttle_pct)@", group = "control"},
        [17] = {name = "@i18n(telemetry.sensor_esc1_voltage)@", group = "esc1"},
        [18] = {name = "@i18n(telemetry.sensor_esc1_current)@", group = "esc1"},
        [19] = {name = "@i18n(telemetry.sensor_esc1_consump)@", group = "esc1"},
        [20] = {name = "@i18n(telemetry.sensor_esc1_erpm)@", group = "esc1"},
        [21] = {name = "@i18n(telemetry.sensor_esc1_pwm)@", group = "esc1"},
        [22] = {name = "@i18n(telemetry.sensor_esc1_throttle)@", group = "esc1"},
        [23] = {name = "@i18n(telemetry.sensor_esc1_temp)@", group = "esc1"},
        [24] = {name = "@i18n(telemetry.sensor_esc1_temp2)@", group = "esc1"},
        [25] = {name = "@i18n(telemetry.sensor_esc1_bec_volt)@", group = "esc1"},
        [26] = {name = "@i18n(telemetry.sensor_esc1_bec_curr)@", group = "esc1"},
        [27] = {name = "@i18n(telemetry.sensor_esc1_status)@", group = "esc1"},
        [28] = {name = "@i18n(telemetry.sensor_esc1_model_id)@", group = "esc1"},
        [30] = {name = "@i18n(telemetry.sensor_esc2_voltage)@", group = "esc2"},
        [31] = {name = "@i18n(telemetry.sensor_esc2_current)@", group = "esc2"},
        [32] = {name = "@i18n(telemetry.sensor_esc2_consump)@", group = "esc2"},
        [33] = {name = "@i18n(telemetry.sensor_esc2_erpm)@", group = "esc2"},
        [36] = {name = "@i18n(telemetry.sensor_esc2_temp)@", group = "esc2"},
        [41] = {name = "@i18n(telemetry.sensor_esc2_model_id)@", group = "esc2"},
        [42] = {name = "@i18n(telemetry.sensor_esc_voltage)@", group = "voltage"},
        [43] = {name = "@i18n(telemetry.sensor_bec_voltage)@", group = "voltage"},
        [44] = {name = "@i18n(telemetry.sensor_bus_voltage)@", group = "voltage"},
        [45] = {name = "@i18n(telemetry.sensor_mcu_voltage)@", group = "voltage"},
        [46] = {name = "@i18n(telemetry.sensor_esc_current)@", group = "current"},
        [47] = {name = "@i18n(telemetry.sensor_bec_current)@", group = "current"},
        [48] = {name = "@i18n(telemetry.sensor_bus_current)@", group = "current"},
        [49] = {name = "@i18n(telemetry.sensor_mcu_current)@", group = "current"},
        [50] = {name = "@i18n(telemetry.sensor_esc_temp)@", group = "temps"},
        [51] = {name = "@i18n(telemetry.sensor_bec_temp)@", group = "temps"},
        [52] = {name = "@i18n(telemetry.sensor_mcu_temp)@", group = "temps"},
        [57] = {name = "@i18n(telemetry.sensor_heading)@", group = "gyro"},
        [58] = {name = "@i18n(telemetry.sensor_altitude)@", group = "barometer"},
        [59] = {name = "@i18n(telemetry.sensor_vspeed)@", group = "barometer"},
        [60] = {name = "@i18n(telemetry.sensor_headspeed)@", group = "rpm"},
        [61] = {name = "@i18n(telemetry.sensor_tailspeed)@", group = "rpm"},
        [64] = {name = "@i18n(telemetry.sensor_attd)@", group = "gyro"},
        [65] = {name = "@i18n(telemetry.sensor_pitch_attitude)@", group = "gyro"},
        [66] = {name = "@i18n(telemetry.sensor_roll_attitude)@", group = "gyro"},
        [67] = {name = "@i18n(telemetry.sensor_yaw_attitude)@", group = "gyro"},
        [68] = {name = "@i18n(telemetry.sensor_accl)@", group = "gyro"},
        [69] = {name = "@i18n(telemetry.sensor_accel_x)@", group = "gyro"},
        [70] = {name = "@i18n(telemetry.sensor_accel_y)@", group = "gyro"},
        [71] = {name = "@i18n(telemetry.sensor_accel_z)@", group = "gyro"},
        [73] = {name = "@i18n(telemetry.sensor_gps_sats)@", group = "gps"},
        [74] = {name = "@i18n(telemetry.sensor_gps_pdop)@", group = "gps"},
        [75] = {name = "@i18n(telemetry.sensor_gps_hdop)@", group = "gps"},
        [76] = {name = "@i18n(telemetry.sensor_gps_vdop)@", group = "gps"},
        [77] = {name = "@i18n(telemetry.sensor_gps_coord)@", group = "gps"},
        [78] = {name = "@i18n(telemetry.sensor_gps_altitude)@", group = "gps"},
        [79] = {name = "@i18n(telemetry.sensor_gps_heading)@", group = "gps"},
        [80] = {name = "@i18n(telemetry.sensor_gps_speed)@", group = "gps"},
        [81] = {name = "@i18n(telemetry.sensor_gps_home_dist)@", group = "gps"},
        [82] = {name = "@i18n(telemetry.sensor_gps_home_dir)@", group = "gps"},
        [85] = {name = "@i18n(telemetry.sensor_cpu_load)@", group = "system"},
        [86] = {name = "@i18n(telemetry.sensor_sys_load)@", group = "system"},
        [87] = {name = "@i18n(telemetry.sensor_rt_load)@", group = "system"},
        [88] = {name = "@i18n(telemetry.sensor_model_id)@", group = "status"},
        [89] = {name = "@i18n(telemetry.sensor_flight_mode)@", group = "status"},
        [90] = {name = "@i18n(telemetry.sensor_arming_flags)@", group = "status"},
        [91] = {name = "@i18n(telemetry.sensor_arming_disable)@", group = "status"},
        [92] = {name = "@i18n(telemetry.sensor_rescue)@", group = "status"},
        [93] = {name = "@i18n(telemetry.sensor_governor)@", group = "status"},
        [95] = {name = "@i18n(telemetry.sensor_pid_profile)@", group = "profiles"},
        [96] = {name = "@i18n(telemetry.sensor_rate_profile)@", group = "profiles"},
        [97] = {name = "@i18n(telemetry.sensor_battery_profile)@", group = "profiles"},
        [98] = {name = "@i18n(telemetry.sensor_led_profile)@", group = "profiles"},
        [99] = {name = "@i18n(telemetry.sensor_adj)@", group = "status"},
        [100] = {name = "@i18n(telemetry.sensor_dbg0)@", group = "debug"},
        [101] = {name = "@i18n(telemetry.sensor_dbg1)@", group = "debug"},
        [102] = {name = "@i18n(telemetry.sensor_dbg2)@", group = "debug"},
        [103] = {name = "@i18n(telemetry.sensor_dbg3)@", group = "debug"},
        [104] = {name = "@i18n(telemetry.sensor_dbg4)@", group = "debug"},
        [105] = {name = "@i18n(telemetry.sensor_dbg5)@", group = "debug"},
        [106] = {name = "@i18n(telemetry.sensor_dbg6)@", group = "debug"},
        [107] = {name = "@i18n(telemetry.sensor_dbg7)@", group = "debug"}
    }

    local groupTitleTag = {
        battery = "@i18n(telemetry.group_battery)@",
        voltage = "@i18n(telemetry.group_voltage)@",
        current = "@i18n(telemetry.group_current)@",
        temps = "@i18n(telemetry.group_temps)@",
        esc1 = "@i18n(telemetry.group_esc1)@",
        esc2 = "@i18n(telemetry.group_esc2)@",
        rpm = "@i18n(telemetry.group_rpm)@",
        barometer = "@i18n(telemetry.group_barometer)@",
        gyro = "@i18n(telemetry.group_gyro)@",
        gps = "@i18n(telemetry.group_gps)@",
        status = "@i18n(telemetry.group_status)@",
        profiles = "@i18n(telemetry.group_profiles)@",
        control = "@i18n(telemetry.group_control)@",
        system = "@i18n(telemetry.group_system)@",
        debug = "@i18n(telemetry.group_debug)@"
    }

    local sensorIds = {}
    for id in pairs(sensorList) do
        sensorIds[#sensorIds + 1] = id
    end
    table.sort(sensorIds, function(a, b) return a < b end)

    local sensorGroups = {}
    for _, id in ipairs(sensorIds) do
        local sensor = sensorList[id]
        local grp = sensor.group or "system"
        if not sensorGroups[grp] then
            sensorGroups[grp] = {
                title = groupTitleTag[grp] or grp,
                ids = {}
            }
        end
        sensorGroups[grp].ids[#sensorGroups[grp].ids + 1] = id
    end

    local groupOrder = {"battery", "voltage", "current", "temps", "esc1", "esc2", "rpm", "barometer", "gyro", "gps", "status", "profiles", "control", "system", "debug"}
    local listed = {}
    for _, grp in ipairs(groupOrder) do
        listed[grp] = true
    end
    local extras = {}
    for grp in pairs(sensorGroups) do
        if not listed[grp] then extras[#extras + 1] = grp end
    end
    table.sort(extras)
    for _, grp in ipairs(extras) do
        groupOrder[#groupOrder + 1] = grp
    end

    TELEMETRY_STATIC_CACHE = {
        sensorList = sensorList,
        sensorIds = sensorIds,
        sensorGroups = sensorGroups,
        groupOrder = groupOrder,
        notAtSameTime = {
            [10] = {11, 12, 13, 14},
            [64] = {65, 66, 67},
            [68] = {69, 70, 71}
        }
    }

    if STATIC_CACHE_HOST then
        STATIC_CACHE_HOST._telemetryStaticCache = TELEMETRY_STATIC_CACHE
    end
end

local SENSOR_LIST = TELEMETRY_STATIC_CACHE.sensorList
local SENSOR_IDS = TELEMETRY_STATIC_CACHE.sensorIds
local SENSOR_GROUPS = TELEMETRY_STATIC_CACHE.sensorGroups
local GROUP_ORDER = TELEMETRY_STATIC_CACHE.groupOrder
local NOT_AT_SAME_TIME = TELEMETRY_STATIC_CACHE.notAtSameTime

local function clearTable(tbl)
    if type(tbl) ~= "table" then return end
    for k in pairs(tbl) do tbl[k] = nil end
end

local function beginLifecycle()
    lifecycleEpoch = lifecycleEpoch + 1
    return lifecycleEpoch
end

local function isLifecycleActive(epoch)
    return epoch == lifecycleEpoch and enableWakeup == true
end

local function trackApi(api)
    if type(api) == "table" then
        activeApiRefSeq = activeApiRefSeq + 1
        activeApiRefs[activeApiRefSeq] = api
    end
    return api
end

local function releaseApiRefs()
    for key, api in pairs(activeApiRefs) do
        if type(api) == "table" then
            if api.setCompleteHandler then pcall(api.setCompleteHandler, NOOP_HANDLER) end
            if api.setErrorHandler then pcall(api.setErrorHandler, NOOP_HANDLER) end
            if api.setUUID then pcall(api.setUUID, nil) end
        end
        activeApiRefs[key] = nil
    end
    activeApiRefSeq = 0
end

local function purgePendingTelemetryMessages()
    local queue = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.mspQueue
    if not (queue and queue.removeQueuedBy) then return end
    queue:removeQueuedBy(function(msg)
        if type(msg) ~= "table" then return false end
        local uuid = msg.uuid
        return type(uuid) == "string" and TELEMETRY_PENDING_UUIDS[uuid] == true
    end)
end

local function clearTelemetryApiEntries()
    local api = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api
    if not api then return end
    if api.clearEntry then
        api.clearEntry("FEATURE_CONFIG")
        api.clearEntry("TELEMETRY_CONFIG")
    end
end

local function clearTelemetryStaticCache()
    if STATIC_CACHE_HOST then
        STATIC_CACHE_HOST._telemetryStaticCache = nil
    end
    if rfsuite and rfsuite.app then
        rfsuite.app._telemetryStaticCache = nil
    end
    if rfsuite then
        rfsuite._telemetryStaticCache = nil
    end

    TELEMETRY_STATIC_CACHE = nil
    SENSOR_LIST = nil
    SENSOR_IDS = nil
    SENSOR_GROUPS = nil
    GROUP_ORDER = nil
    NOT_AT_SAME_TIME = nil
end

local function isLinkReady()
    local liveSession = rfsuite.session
    return (liveSession and liveSession.isConnected and liveSession.mcu_id and liveSession.postConnectComplete) and true or false
end

local function snapshotConfig(src, dst)
    if type(src) ~= "table" or type(dst) ~= "table" then return end
    saveDirtyOverride = false
    clearTable(dst)
    for _, id in ipairs(SENSOR_IDS) do
        dst[id] = (src[id] == true)
    end
end

local function hasConfigChanges()
    local changed = false
    for _, id in ipairs(SENSOR_IDS) do
        if (config[id] == true) ~= (SAVED_CONFIG[id] == true) then
            changed = true
            break
        end
    end
    return changed or saveDirtyOverride
end

local function refreshSaveState()
    if rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.setPageDirty then
        rfsuite.app.ui.setPageDirty(hasConfigChanges())
    end
end

local function setFormFieldsEnabled(enabled)
    if not (rfsuite.app and rfsuite.app.formFields) then return end
    for _, field in pairs(rfsuite.app.formFields) do
        if field and field.enable then field:enable(enabled == true) end
    end
end

local function resetConfigRuntimeState()
    configLoading = false
    triggerSave = false
    setDefaultSensors = false
    pendingSaveStateRefresh = 0
    saveDirtyOverride = false
    FEATURE_ENABLED_BITMAP = nil
    clearTable(telemetryBuffer)
    clearTable(PREV_STATE)
    clearTable(config)
    clearTable(SAVED_CONFIG)
    if rfsuite.app and rfsuite.app.Page then
        rfsuite.app.Page.configLoaded = false
    end
    setFormFieldsEnabled(false)
    refreshSaveState()
end

local function countEnabledSensors()
    local count = 0
    for _, v in pairs(config) do if v == true then count = count + 1 end end
    return count
end

local function alertIfTooManySensors()
    local buttons = {{label = "@i18n(app.modules.profile_select.ok)@", action = function() return true end}}

    form.openDialog({width = nil, title = "@i18n(app.modules.telemetry.name)@", message = "@i18n(app.modules.telemetry.no_more_than_40)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
end

local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script
    form.clear()

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    local headerTitle = title
    if type(headerTitle) ~= "string" or headerTitle == "" then
        headerTitle = "@i18n(app.modules.telemetry.name)@"
    end
    rfsuite.app.ui.fieldHeader(headerTitle)

    rfsuite.app.formLineCnt = 0

    local app = rfsuite.app
    clearTable(app.formFields)
    clearTable(app.formLines)

    if rfsuite.utils.apiVersionCompare("<", {12, 0, 8}) then
        rfsuite.app.triggers.closeProgressLoader = true

        rfsuite.app.formLines[#rfsuite.app.formLines + 1] = form.addLine("@i18n(app.modules.telemetry.invalid_version)@")

        rfsuite.app.formNavigationFields["save"]:enable(false)
        rfsuite.app.formNavigationFields["reload"]:enable(false)

        return
    end

    local formFieldCount = 0

    for _, key in ipairs(GROUP_ORDER) do
        local group = SENSOR_GROUPS[key]
        if group and group.ids and #group.ids > 0 then
            local panel = form.addExpansionPanel(group.title)
            panel:open(false)
            for _, id in ipairs(group.ids) do
                local sensor = SENSOR_LIST[id]
                if sensor then
                    local sensorId = id
                    local line = panel:addLine(sensor.name)
                    formFieldCount = id
                    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1

                    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function() return config[sensorId] or false end, function(val)
                        local count = countEnabledSensors()
                        if count > 40 then
                            alertIfTooManySensors()
                            return false
                        end

                        if val == true and NOT_AT_SAME_TIME[sensorId] then

                            for _, conflictId in ipairs(NOT_AT_SAME_TIME[sensorId]) do

                                PREV_STATE[conflictId] = config[conflictId]

                                config[conflictId] = false
                                if rfsuite.app.formFields[conflictId] then rfsuite.app.formFields[conflictId]:enable(false) end
                            end
                        elseif val == false and NOT_AT_SAME_TIME[sensorId] then

                            for _, conflictId in ipairs(NOT_AT_SAME_TIME[sensorId]) do
                                if rfsuite.app.formFields[conflictId] then rfsuite.app.formFields[conflictId]:enable(true) end

                                if PREV_STATE[conflictId] ~= nil then
                                    config[conflictId] = PREV_STATE[conflictId]
                                    PREV_STATE[conflictId] = nil
                                end
                            end
                        end

                        config[sensorId] = val
                        saveDirtyOverride = false
                        refreshSaveState()
                    end)
                    rfsuite.app.formFields[formFieldCount]:enable(false)
                end
            end
        end
    end

    beginLifecycle()
    enableWakeup = true
    lastSessionRef = rfsuite.session
    lastLinkReady = isLinkReady()
end

local function rebootFC()
    local epoch = lifecycleEpoch
    local RAPI = trackApi(rfsuite.tasks.msp.api.loadPage("REBOOT"))
    RAPI.setUUID("telemetry-reboot")
    RAPI.setCompleteHandler(function(self)
        if not isLifecycleActive(epoch) then return end
        rfsuite.utils.log("Rebooting FC", "info")
        rfsuite.utils.onReboot()
    end)
    RAPI.write()
end

local function applySettings()
    local epoch = lifecycleEpoch
    local EAPI = trackApi(rfsuite.tasks.msp.api.loadPage("EEPROM_WRITE"))
    EAPI.setUUID("telemetry-eeprom")
    EAPI.setCompleteHandler(function(self)
        if not isLifecycleActive(epoch) then return end
        rfsuite.utils.log("Writing to EEPROM", "info")
        rebootFC()
    end)
    EAPI.write()

    rfsuite.app.triggers.closeSaveFake = true
end

local function getDefaultSensors(sensorListFromApi)
    local defaultSensors = {}
    for _, sensor in pairs(sensorListFromApi) do
        if (sensor["mandatory"] == true or sensor["default_telemetry_sensor"] == true) and sensor["set_telemetry_sensors"] ~= nil then
            local sensorId = tonumber(sensor["set_telemetry_sensors"])
            if sensorId then
                table.insert(defaultSensors, sensorId)
            end
        end
    end
    return defaultSensors
end

local function applyDefaultSensors()
    local sensorListFromApi = getDefaultSensors(rfsuite.tasks.telemetry.listSensors() or {})
    local defaultSet = {}

    for _, v in ipairs(sensorListFromApi) do
        local sensorId = tonumber(v)
        if sensorId then
            defaultSet[sensorId] = true
        end
    end

    for _, id in ipairs(SENSOR_IDS) do
        local desired = defaultSet[id] == true
        if (config[id] == true) ~= desired then
            config[id] = desired
        end
    end

    -- "Apply defaults" is treated as an explicit user action that should always
    -- allow save/re-apply, even if values are already at defaults.
    saveDirtyOverride = true
    refreshSaveState()
    if form and form.invalidate then form.invalidate() end
    return true
end

local function wakeup()
    if enableWakeup == false then return end

    local linkReady = isLinkReady()
    local liveSession = rfsuite.session

    if liveSession ~= lastSessionRef then
        lastSessionRef = liveSession
        resetConfigRuntimeState()
    elseif lastLinkReady ~= linkReady then
        if not linkReady then
            resetConfigRuntimeState()
        elseif rfsuite.app and rfsuite.app.Page then
            rfsuite.app.Page.configLoaded = false
            configLoading = false
        end
    end
    lastLinkReady = linkReady

    if linkReady and not rfsuite.app.Page.configLoaded and not configLoading then
        configLoading = true
        local epoch = lifecycleEpoch

        -- first load the feature config 
        local FAPI = trackApi(rfsuite.tasks.msp.api.loadPage("FEATURE_CONFIG"))
        FAPI.setCompleteHandler(function(self, buf)
                if not isLifecycleActive(epoch) then return end
                local d = FAPI.data()
                FEATURE_ENABLED_BITMAP = nil
                if d and type(d.parsed) == "table" then
                    FEATURE_ENABLED_BITMAP = tonumber(d.parsed.enabledFeatures)
                end
                rfsuite.utils.log("Feature config loaded", "info")
        end)
        FAPI.setUUID("telemetry-feature-read")
        FAPI.read()

        -- now load the telemetry config
        local API = trackApi(rfsuite.tasks.msp.api.loadPage("TELEMETRY_CONFIG"))
        API.setCompleteHandler(function(self, buf)
            if not isLifecycleActive(epoch) then return end
            if rfsuite.app.Page then
                setFormFieldsEnabled(true)

                local data = API.data()
                if type(data) == "table" then
                    clearTable(telemetryBuffer)
                    if type(data.buffer) == "table" then
                        for i = 1, #data.buffer do
                            telemetryBuffer[i] = data.buffer[i]
                        end
                    end
                end

                clearTable(config)
                if data and type(data.parsed) == "table" then
                    for key, value in pairs(data.parsed) do
                        if string.match(key, "^telem_sensor_slot_%d+$") then
                            local sensorId = tonumber(value)
                            if sensorId and sensorId ~= 0 then
                                rfsuite.app.Page.config[sensorId] = true
                            end
                        end
                    end
                end

                snapshotConfig(config, SAVED_CONFIG)
                refreshSaveState()
                rfsuite.app.Page.configLoaded = true
            end

            configLoading = false
            rfsuite.utils.log("Telemetry config loaded", "info")
            rfsuite.app.triggers.closeProgressLoader = true
        end)
        API.setErrorHandler(function()
            if not isLifecycleActive(epoch) then return end
            configLoading = false
            if rfsuite.app and rfsuite.app.Page then
                if isLinkReady() then
                    rfsuite.app.Page.configLoaded = true
                    snapshotConfig(config, SAVED_CONFIG)
                else
                    rfsuite.app.Page.configLoaded = false
                    clearTable(config)
                    clearTable(SAVED_CONFIG)
                    setFormFieldsEnabled(false)
                end
                refreshSaveState()
            end
            rfsuite.utils.log("Telemetry config load failed", "error")
            rfsuite.app.triggers.closeProgressLoader = true
        end)
        API.setUUID("telemetry-config-read")
        API.read()
    end

    if triggerSave == true then
        rfsuite.app.ui.progressDisplaySave("@i18n(app.modules.profile_select.save_settings)@")


        -- ensure telemetry feature is enabled (FEATURE_CONFIG bit 10)
        if FEATURE_ENABLED_BITMAP ~= nil then

            local FEATURE_TELEMETRY_BIT  = 10
            local FEATURE_TELEMETRY_MASK = 2 ^ FEATURE_TELEMETRY_BIT

            local bitmap = FEATURE_ENABLED_BITMAP
            local telemetryEnabled =
                (math.floor(bitmap / FEATURE_TELEMETRY_MASK) % 2) == 1

            if not telemetryEnabled then
                rfsuite.utils.log("Telemetry feature disabled – enabling", "info")

                local newBitmap = bitmap | FEATURE_TELEMETRY_MASK

                local FAPI = trackApi(rfsuite.tasks.msp.api.loadPage("FEATURE_CONFIG"))
                FAPI.setUUID("enable-telemetry-feature")
                FAPI.setValue("enabledFeatures", newBitmap)
                FAPI.write()

                -- update local snapshot so subsequent logic sees it enabled
                FEATURE_ENABLED_BITMAP = newBitmap
            end
        end


        -- write the sensors
        local selectedSensors = {}

        for k, v in pairs(config) do
            if v == true then
                local sensorId = tonumber(k)
                if sensorId then table.insert(selectedSensors, sensorId) end
            end
        end

        local epoch = lifecycleEpoch
        local WRITEAPI = trackApi(rfsuite.tasks.msp.api.loadPage("TELEMETRY_CONFIG"))
        WRITEAPI.setUUID("telemetry-config-write")
        WRITEAPI.setCompleteHandler(function(self, buf)
            if not isLifecycleActive(epoch) then return end
            rfsuite.utils.log("Telemetry config written, now writing to EEPROM", "info")
            snapshotConfig(config, SAVED_CONFIG)
            refreshSaveState()
            applySettings()
        end)
        WRITEAPI.setErrorHandler(function(self, buf)
            if not isLifecycleActive(epoch) then return end
            rfsuite.utils.log("Write to fbl failed.", "info")
        end)

        local buffer = {}
        for i = 1, 52 do
            buffer[i] = telemetryBuffer[i] or 0
        end

        local sensorIndex = 13

        local appliedSensors = {}

        for _, sensor_id in ipairs(selectedSensors) do
            if sensorIndex <= 52 then
                buffer[sensorIndex] = sensor_id
                table.insert(appliedSensors, sensor_id)
                sensorIndex = sensorIndex + 1
            else
                break
            end
        end

        for i = sensorIndex, 52 do buffer[i] = 0 end

        rfsuite.session = rfsuite.session or {}
        rfsuite.session.telemetryConfig = appliedSensors

        rfsuite.utils.log("Applied telemetry sensors: " .. table.concat(appliedSensors, ", "), "info")

        WRITEAPI.write(buffer)        

        triggerSave = false
    end

    if setDefaultSensors == true and rfsuite.app.Page.configLoaded then
        local changed = applyDefaultSensors()
        if changed and rfsuite.app and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["save"] and rfsuite.app.formNavigationFields["save"].enable then
            rfsuite.app.formNavigationFields["save"]:enable(true)
            pendingSaveStateRefresh = 5
        end
        setDefaultSensors = false
    end

    if pendingSaveStateRefresh > 0 then
        pendingSaveStateRefresh = pendingSaveStateRefresh - 1
        refreshSaveState()
        if hasConfigChanges() and rfsuite.app and rfsuite.app.formNavigationFields and rfsuite.app.formNavigationFields["save"] and rfsuite.app.formNavigationFields["save"].enable then
            rfsuite.app.formNavigationFields["save"]:enable(true)
        end
    end
end

local function close()
    beginLifecycle()
    enableWakeup = false
    purgePendingTelemetryMessages()
    releaseApiRefs()
    clearTelemetryApiEntries()
    if rfsuite.app and rfsuite.app.triggers then
        rfsuite.app.triggers.closeProgressLoader = true
        rfsuite.app.triggers.closeProgressLoaderNoisProcessed = true
        rfsuite.app.triggers.closeSave = true
        rfsuite.app.triggers.closeSaveFake = true
    end
    resetConfigRuntimeState()
    lastSessionRef = nil
    lastLinkReady = false
    clearTelemetryStaticCache()
end

local function onSaveMenu()

    if rfsuite.preferences.general.save_confirm == false or rfsuite.preferences.general.save_confirm == "false" then
        triggerSave = true
        return
    end  

    local buttons = {
        {
            label = "@i18n(app.btn_ok_long)@",
            action = function()
                triggerSave = true
                return true
            end
        }, {
            label = "@i18n(app.modules.profile_select.cancel)@",
            action = function()
                triggerSave = false
                return true
            end
        }
    }

    form.openDialog({width = nil, title = "@i18n(app.modules.profile_select.save_settings)@", message = "@i18n(app.modules.profile_select.save_prompt)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

    triggerSave = false
end

local function onToolMenu(self)
    local buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()
                setDefaultSensors = true
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }

    form.openDialog({width = nil, title = "@i18n(app.modules.telemetry.name)@", message = "@i18n(app.modules.telemetry.msg_set_defaults)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
end

local function mspSuccess() end

local function mspRetry() end

local function onReloadMenu() rfsuite.app.triggers.triggerReloadFull = true end

return {apidata = apidata, openPage = openPage, eepromWrite = true, mspSuccess = mspSuccess, mspRetry = mspRetry, onSaveMenu = onSaveMenu, onToolMenu = onToolMenu, onReloadMenu = onReloadMenu, reboot = false, wakeup = wakeup, close = close, API = {}, config = config, configLoaded = configLoaded, configApplied = configApplied, canSave = hasConfigChanges, navButtons = {menu = true, save = true, reload = true, tool = true, help = false}}
