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
local configApplied = false
local setDefaultSensors = false
local PREV_STATE = {}
local FEATURE_CONFIG

local sensorList = {
    [1] = { name = "Heartbeat", group = "system" },
    [3] = { name = "Voltage", group = "battery" },
    [4] = { name = "Current", group = "battery" },
    [5] = { name = "Consumption", group = "battery" },
    [6] = { name = "Charge Level", group = "battery" },
    [7] = { name = "Cell Count", group = "battery" },
    [8] = { name = "Cell Voltage", group = "battery" },
    [9] = { name = "Cell Voltages", group = "battery" },
    [10] = { name = "Ctrl", group = "control" },
    [11] = { name = "Pitch Control", group = "control" },
    [12] = { name = "Roll Control", group = "control" },
    [13] = { name = "Yaw Control", group = "control" },
    [14] = { name = "Coll Control", group = "control" },
    [15] = { name = "Throttle %", group = "control" },
    [17] = { name = "ESC1 Voltage", group = "esc1" },
    [18] = { name = "ESC1 Current", group = "esc1" },
    [19] = { name = "ESC1 Consump", group = "esc1" },
    [20] = { name = "ESC1 eRPM", group = "esc1" },
    [21] = { name = "ESC1 PWM", group = "esc1" },
    [22] = { name = "ESC1 Throttle", group = "esc1" },
    [23] = { name = "ESC1 Temp", group = "esc1" },
    [24] = { name = "ESC1 Temp 2", group = "esc1" },
    [25] = { name = "ESC1 BEC Volt", group = "esc1" },
    [26] = { name = "ESC1 BEC Curr", group = "esc1" },
    [27] = { name = "ESC1 Status", group = "esc1" },
    [28] = { name = "ESC1 Model ID", group = "esc1" },
    [30] = { name = "ESC2 Voltage", group = "esc2" },
    [31] = { name = "ESC2 Current", group = "esc2" },
    [32] = { name = "ESC2 Consump", group = "esc2" },
    [33] = { name = "ESC2 eRPM", group = "esc2" },
    [36] = { name = "ESC2 Temp", group = "esc2" },
    [41] = { name = "ESC2 Model ID", group = "esc2" },
    [42] = { name = "ESC Voltage", group = "voltage" },
    [43] = { name = "BEC Voltage", group = "voltage" },
    [44] = { name = "BUS Voltage", group = "voltage" },
    [45] = { name = "MCU Voltage", group = "voltage" },
    [46] = { name = "ESC Current", group = "current" },
    [47] = { name = "BEC Current", group = "current" },
    [48] = { name = "BUS Current", group = "current" },
    [49] = { name = "MCU Current", group = "current" },
    [50] = { name = "ESC Temp", group = "temps" },
    [51] = { name = "BEC Temp", group = "temps" },
    [52] = { name = "MCU Temp", group = "temps" },
    [57] = { name = "Heading", group = "gyro" },
    [58] = { name = "Altitude", group = "barometer" },
    [59] = { name = "VSpeed", group = "barometer" },
    [60] = { name = "Headspeed", group = "rpm" },
    [61] = { name = "Tailspeed", group = "rpm" },
    [64] = { name = "Attd", group = "gyro" },
    [65] = { name = "Pitch Attitude", group = "gyro" },
    [66] = { name = "Roll Attitude", group = "gyro" },
    [67] = { name = "Yaw Attitude", group = "gyro" },
    [68] = { name = "Accl", group = "gyro" },
    [69] = { name = "Accel X", group = "gyro" },
    [70] = { name = "Accel Y", group = "gyro" },
    [71] = { name = "Accel Z", group = "gyro" },
    [73] = { name = "GPS Sats", group = "gps" },
    [74] = { name = "GPS PDOP", group = "gps" },
    [75] = { name = "GPS HDOP", group = "gps" },
    [76] = { name = "GPS VDOP", group = "gps" },
    [77] = { name = "GPS Coord", group = "gps" },
    [78] = { name = "GPS Altitude", group = "gps" },
    [79] = { name = "GPS Heading", group = "gps" },
    [80] = { name = "GPS Speed", group = "gps" },
    [81] = { name = "GPS Home Dist", group = "gps" },
    [82] = { name = "GPS Home Dir", group = "gps" },
    [85] = { name = "CPU Load", group = "system" },
    [86] = { name = "SYS Load", group = "system" },
    [87] = { name = "RT Load", group = "system" },
    [88] = { name = "Model ID", group = "status" },
    [89] = { name = "Flight Mode", group = "status" },
    [90] = { name = "Arming Flags", group = "status" },
    [91] = { name = "Arming Disable", group = "status" },
    [92] = { name = "Rescue", group = "status" },
    [93] = { name = "Governor", group = "status" },
    [95] = { name = "PID Profile", group = "profiles" },
    [96] = { name = "Rate Profile", group = "profiles" },
    [98] = { name = "LED Profile", group = "profiles" },
    [99] = { name = "ADJ", group = "status" },
    [100] = { name = "DBG0", group = "debug" },
    [101] = { name = "DBG1", group = "debug" },
    [102] = { name = "DBG2", group = "debug" },
    [103] = { name = "DBG3", group = "debug" },
    [104] = { name = "DBG4", group = "debug" },
    [105] = { name = "DBG5", group = "debug" },
    [106] = { name = "DBG6", group = "debug" },
    [107] = { name = "DBG7", group = "debug" }
}

local TELEMETRY_SENSORS = {}
do
    for id, s in pairs(sensorList) do

        local displayName = s.name or ("Sensor " .. tostring(id))
        TELEMETRY_SENSORS[id] = {name = displayName, id = id, group = s.group or "system"}
    end
end

local GROUP_TITLE_TAG = {
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

local function buildGroups(list)
    local groups = {}
    for id, s in pairs(list) do
        local grp = s.group or "system"
        if not groups[grp] then

            local title = GROUP_TITLE_TAG[grp] or grp
            groups[grp] = {title = title, ids = {}}
        end
        table.insert(groups[grp].ids, id)
    end

    for _, g in pairs(groups) do table.sort(g.ids, function(a, b) return a < b end) end
    return groups
end

local SENSOR_GROUPS = buildGroups(sensorList)

local NOT_AT_SAME_TIME = {[10] = {11, 12, 13, 14}, [64] = {65, 66, 67}, [68] = {69, 70, 71}}

local GROUP_ORDER = {"battery", "voltage", "current", "temps", "esc1", "esc2", "rpm", "barometer", "gyro", "gps", "status", "profiles", "control", "system", "debug"}

do
    local listed = {}
    for _, g in ipairs(GROUP_ORDER) do listed[g] = true end
    local extras = {}
    for g, _ in pairs(SENSOR_GROUPS) do if not listed[g] then table.insert(extras, g) end end
    table.sort(extras)
    for _, g in ipairs(extras) do table.insert(GROUP_ORDER, g) end
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
    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    if rfsuite.utils.apiVersionCompare("<", "12.08") then
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
                local sensor = TELEMETRY_SENSORS[id]
                if sensor then
                    local line = panel:addLine(sensor.name)
                    formFieldCount = id
                    rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1

                    rfsuite.app.formFields[formFieldCount] = form.addBooleanField(line, nil, function() return config[sensor.id] or false end, function(val)
                        local count = countEnabledSensors()
                        if count > 40 then
                            alertIfTooManySensors()
                            return false
                        end

                        if val == true and NOT_AT_SAME_TIME[sensor.id] then

                            for _, conflictId in ipairs(NOT_AT_SAME_TIME[sensor.id]) do

                                PREV_STATE[conflictId] = config[conflictId]

                                config[conflictId] = false
                                if rfsuite.app.formFields[conflictId] then rfsuite.app.formFields[conflictId]:enable(false) end
                            end
                        elseif val == false and NOT_AT_SAME_TIME[sensor.id] then

                            for _, conflictId in ipairs(NOT_AT_SAME_TIME[sensor.id]) do
                                if rfsuite.app.formFields[conflictId] then rfsuite.app.formFields[conflictId]:enable(true) end

                                if PREV_STATE[conflictId] ~= nil then
                                    config[conflictId] = PREV_STATE[conflictId]
                                    PREV_STATE[conflictId] = nil
                                end
                            end
                        end

                        config[sensor.id] = val
                    end)
                    rfsuite.app.formFields[formFieldCount]:enable(false)
                end
            end
        end
    end

    enableWakeup = true
end

local function rebootFC()
    local RAPI = rfsuite.tasks.msp.api.load("REBOOT")
    RAPI.setUUID("123e4567-e89b-12d3-a456-426614174000")
    RAPI.setCompleteHandler(function(self)
        rfsuite.utils.log("Rebooting FC", "info")
        rfsuite.utils.onReboot()
    end)
    RAPI.write()
end

local function applySettings()
    local EAPI = rfsuite.tasks.msp.api.load("EEPROM_WRITE")
    EAPI.setUUID("550e8400-e29b-41d4-a716-446655440000")
    EAPI.setCompleteHandler(function(self)
        rfsuite.utils.log("Writing to EEPROM", "info")
        rebootFC()
    end)
    EAPI.write()

    rfsuite.app.triggers.closeSaveFake = true
end

local function getDefaultSensors(sensorListFromApi)
    local defaultSensors = {}
    local i = 0
    for _, sensor in pairs(sensorListFromApi) do
        if sensor["mandatory"] == true and sensor["set_telemetry_sensors"] ~= nil then
            defaultSensors[i] = sensor["set_telemetry_sensors"]
            i = i + 1
        end
    end
    return defaultSensors
end

local function applyDefaultSensors()
    local sensorListFromApi = getDefaultSensors(rfsuite.tasks.telemetry.listSensors())
    local changed = false

    for _, v in pairs(sensorListFromApi) do
        if config[v] ~= true then
            config[v] = true
            changed = true
        end
    end

    if changed and rfsuite.app and rfsuite.app.ui and rfsuite.app.ui.markPageDirty then
        rfsuite.app.ui.markPageDirty()
    end
end

-- shallow-copy helper (snapshots tables so API internals can’t mutate our cache)
local function copyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
    dst[k] = v
    end
    return dst
end

local function wakeup()
    if enableWakeup == false then return end

    if not rfsuite.app.Page.configLoaded then

        -- first load the feature config 
        local FAPI = rfsuite.tasks.msp.api.load("FEATURE_CONFIG")
        FAPI.setCompleteHandler(function(self, buf)
                -- store the snapshot of the feature config
                local d = FAPI.data()
                FEATURE_CONFIG = {}
                FEATURE_CONFIG['values']             = copyTable(d.parsed)
                FEATURE_CONFIG['structure']          = copyTable(d.structure)
                FEATURE_CONFIG['buffer']             = copyTable(d.buffer)
                FEATURE_CONFIG['receivedBytesCount'] = d.receivedBytesCount
                FEATURE_CONFIG['positionmap']        = copyTable(d.positionmap)
                FEATURE_CONFIG['other']              = copyTable(d.other)

                rfsuite.utils.log("Feature config loaded", "info")
        end)
        FAPI.setUUID("d2a1c5b3-8f4a-3c8e-9d2a-3b6f8e2d9a1c")
        FAPI.read()

        -- now load the telemetry config
        local API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
        API.setCompleteHandler(function(self, buf)
            local hasData = API.readValue("telem_sensor_slot_40")
            if hasData then
                if rfsuite.app.Page then

                    if rfsuite.app.formFields then for i, v in pairs(rfsuite.app.formFields) do if v and v.enable then v:enable(true) end end end

                    local data = API.data()
                    rfsuite.tasks.msp.api.apidata = data
                    rfsuite.tasks.msp.api.apidata.receivedBytes = {}
                    rfsuite.tasks.msp.api.apidata.receivedBytesCount = {}

                    for _, value in pairs(data.parsed) do if value ~= 0 then rfsuite.app.Page.config[value] = true end end
                end

                rfsuite.utils.log("Telemetry config loaded", "info")
                rfsuite.app.triggers.closeProgressLoader = true
            end
        end)
        API.setUUID("a23e4567-e89b-12d3-a456-426614174001")
        API.read()

        rfsuite.app.Page.configLoaded = true
    end

    if triggerSave == true then
        rfsuite.app.ui.progressDisplaySave("@i18n(app.modules.profile_select.save_settings)@")


        -- ensure telemetry feature is enabled (FEATURE_CONFIG bit 10)
        if FEATURE_CONFIG and FEATURE_CONFIG.values and FEATURE_CONFIG.values.enabledFeatures then

            local FEATURE_TELEMETRY_BIT  = 10
            local FEATURE_TELEMETRY_MASK = 2 ^ FEATURE_TELEMETRY_BIT

            local bitmap = FEATURE_CONFIG.values.enabledFeatures
            local telemetryEnabled =
                (math.floor(bitmap / FEATURE_TELEMETRY_MASK) % 2) == 1

            if not telemetryEnabled then
                rfsuite.utils.log("Telemetry feature disabled – enabling", "info")

                local newBitmap = bitmap | FEATURE_TELEMETRY_MASK

                local FAPI = rfsuite.tasks.msp.api.load("FEATURE_CONFIG")
                FAPI.setUUID("enable-telemetry-feature")
                FAPI.setValue("enabledFeatures", newBitmap)
                FAPI.write()

                -- update local snapshot so subsequent logic sees it enabled
                FEATURE_CONFIG.values.enabledFeatures = newBitmap
            end
        end


        -- write the sensors
        local selectedSensors = {}

        for k, v in pairs(config) do if v == true then table.insert(selectedSensors, k) end end

        local WRITEAPI = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
        WRITEAPI.setUUID("123e4567-e89b-12d3-a456-426614174120")
        WRITEAPI.setCompleteHandler(function(self, buf)
            rfsuite.utils.log("Telemetry config written, now writing to EEPROM", "info")
            applySettings()
        end)
        WRITEAPI.setErrorHandler(function(self, buf) rfsuite.utils.log("Write to fbl failed.", "info") end)

        local buffer = rfsuite.tasks.msp.api.apidata["buffer"]

        local slotsStrBefore = table.concat(buffer, ",")

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

        local slotsStrAfter = table.concat(buffer, ",")

        for i = sensorIndex, 52 do buffer[i] = 0 end

        rfsuite.session = rfsuite.session or {}
        rfsuite.session.telemetryConfig = appliedSensors

        rfsuite.utils.log("Applied telemetry sensors: " .. table.concat(appliedSensors, ", "), "info")

        WRITEAPI.write(buffer)        

        triggerSave = false
    end

    if setDefaultSensors == true then
        applyDefaultSensors()
        setDefaultSensors = false
    end

    if setDefaultSensors == true then
        applyDefaultSensors()
        setDefaultSensors = false
    end
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

return {apidata = apidata, openPage = openPage, eepromWrite = true, mspSuccess = mspSuccess, mspRetry = mspRetry, onSaveMenu = onSaveMenu, onToolMenu = onToolMenu, onReloadMenu = onReloadMenu, reboot = false, wakeup = wakeup, API = {}, config = config, configLoaded = configLoaded, configApplied = configApplied, navButtons = {menu = true, save = true, reload = true, tool = true, help = false}}
