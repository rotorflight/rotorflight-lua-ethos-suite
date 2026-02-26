--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local lcd = lcd
local app = rfsuite.app
local tasks = rfsuite.tasks
local rfutils = rfsuite.utils
local session = rfsuite.session

local enableWakeup = false

local w, h = lcd.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

local displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = app.radio.linePaddingTop, w = 100, h = app.radio.navbuttonHeight}

local invalidSensors = tasks.telemetry.validateSensors()

local repairSensors = false

local sensorTlm = nil

local progressLoader
local progressLoaderCounter = 0
local progressLoaderBaseMessage
local progressLoaderMspStatusLast
local doDiscoverNotify = false

local function openProgressDialog(...)
    if rfutils.ethosVersionAtLeast({26, 1, 0}) and form.openWaitDialog then
        local arg1 = select(1, ...)
        if type(arg1) == "table" then
            arg1.progress = true
            return form.openWaitDialog(arg1)
        end
        local title = arg1
        local message = select(2, ...)
        return form.openWaitDialog({title = title, message = message, progress = true})
    end
    return form.openProgressDialog(...)
end

local function sortSensorListByName(sensorList)
    table.sort(sensorList, function(a, b) return a.name:lower() < b.name:lower() end)
    return sensorList
end

local sensorList = sortSensorListByName(tasks.telemetry.listSensors())

local function openPage(opts)

    local pidx = opts.idx
    local title = opts.title
    local script = opts.script
    enableWakeup = false
    app.triggers.closeProgressLoader = true

    form.clear()

    app.lastIdx = pidx
    app.lastTitle = title
    app.lastScript = script

    app.ui.fieldHeader("@i18n(app.modules.diagnostics.name)@" .. " / " .. "@i18n(app.modules.validate_sensors.name)@")

    app.formLineCnt = 0

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    local posText = {x = x - 5 - buttonW - buttonWs, y = app.radio.linePaddingTop, w = 200, h = app.radio.navbuttonHeight}
    for i, v in ipairs(sensorList or {}) do
        app.formLineCnt = app.formLineCnt + 1
        app.formLines[app.formLineCnt] = form.addLine(v.name)
        app.formFields[v.key] = form.addStaticText(app.formLines[app.formLineCnt], posText, "-")
    end

    enableWakeup = true
end

local function sensorKeyExists(searchKey, sensorTable)
    if type(sensorTable) ~= "table" then return false end

    for _, sensor in pairs(sensorTable) do if sensor['key'] == searchKey then return true end end

    return false
end

local function postLoad(self) rfutils.log("postLoad", "debug") end

local function postRead(self) rfutils.log("postRead", "debug") end

local function rebootFC()

    local RAPI = tasks.msp.api.load("REBOOT")
    RAPI.setUUID("123e4567-e89b-12d3-a456-426614174000")
    RAPI.setCompleteHandler(function(self)
        rfutils.log("Rebooting FC", "info")

        rfutils.onReboot()

    end)
    RAPI.write()

end

local function applySettings()
    local EAPI = tasks.msp.api.load("EEPROM_WRITE")
    EAPI.setUUID("550e8400-e29b-41d4-a716-446655440000")
    EAPI.setCompleteHandler(function(self)
        rfutils.log("Writing to EEPROM", "info")
        rebootFC()
    end)
    EAPI.write()

end

local function runRepair(data)

    local sensorList = tasks.telemetry.listSensors()
    local newSensorList = {}

    local count = 1
    for _, v in pairs(sensorList) do
        local sensor_id = v['set_telemetry_sensors']
        if sensor_id ~= nil and not newSensorList[sensor_id] then
            newSensorList[sensor_id] = true
            count = count + 1
        end
    end

    for i, v in pairs(data['parsed']) do
        if string.match(i, "^telem_sensor_slot_%d+$") and v ~= 0 then
            local sensor_id = v
            if sensor_id ~= nil and not newSensorList[sensor_id] then
                newSensorList[sensor_id] = true
                count = count + 1
            end
        end
    end

    local WRITEAPI = tasks.msp.api.load("TELEMETRY_CONFIG")
    WRITEAPI.setUUID("123e4567-e89b-12d3-a456-426614174000")
    WRITEAPI.setCompleteHandler(function(self, buf) applySettings() end)

    local buffer = data['buffer']
    local sensorIndex = 13

    local sortedSensorIds = {}
    for sensor_id, _ in pairs(newSensorList) do table.insert(sortedSensorIds, sensor_id) end

    table.sort(sortedSensorIds)

    for _, sensor_id in ipairs(sortedSensorIds) do
        if sensorIndex <= 52 then
            buffer[sensorIndex] = sensor_id
            sensorIndex = sensorIndex + 1
        else
            break
        end
    end

    for i = sensorIndex, 52 do buffer[i] = 0 end

    WRITEAPI.write(buffer)

end

local function updateProgressLoaderMessage()
    if not progressLoader or not progressLoaderBaseMessage then return end
    if app and app.ui and app.ui.updateProgressDialogMessage then
        app.ui.updateProgressDialogMessage()
    end
end

local function wakeup()

    if enableWakeup == false then return end

    if doDiscoverNotify == true then

        if not sensorTlm then
            if not session.telemetrySensor then return false end

            sensorTlm = sport.getSensor()
            sensorTlm:module(session.telemetrySensor:module())

            if not sensorTlm then return false end
        end

        doDiscoverNotify = false

        local buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}}

        if rfutils.ethosVersionAtLeast({1, 6, 3}) then
            rfutils.log("Starting discover sensors", "info")
            sensorTlm:discover()
        else
            form.openDialog({width = nil, title = "@i18n(app.modules.validate_sensors.name)@", message = "@i18n(app.modules.validate_sensors.msg_repair_fin)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
        end
    end

    invalidSensors = tasks.telemetry.validateSensors()

    for i, v in ipairs(sensorList) do

        local field = app.formFields and app.formFields[v.key]
        if field then
            if sensorKeyExists(v.key, invalidSensors) then
                if v.mandatory == true then
                    field:value("@i18n(app.modules.validate_sensors.invalid)@")
                    field:color(ORANGE)
                else
                    field:value("@i18n(app.modules.validate_sensors.invalid)@")
                    field:color(RED)
                end
            else
                field:value("@i18n(app.modules.validate_sensors.ok)@")
                field:color(GREEN)
            end
        end
    end

    if repairSensors == true then

        progressLoader = openProgressDialog("@i18n(app.msg_saving)@", "@i18n(app.msg_saving_to_fbl)@")
        progressLoader:closeAllowed(false)
        progressLoaderCounter = 0
        progressLoaderBaseMessage = "@i18n(app.msg_saving_to_fbl)@"
        progressLoaderMspStatusLast = nil
        updateProgressLoaderMessage()
        app.ui.registerProgressDialog(progressLoader, progressLoaderBaseMessage)

        API = tasks.msp.api.load("TELEMETRY_CONFIG")
        API.setUUID("550e8400-e29b-41d4-a716-446655440000")
        API.setCompleteHandler(function(self, buf)
            local data = API.data()
            if data['parsed'] then runRepair(data) end
        end)
        API.read()
        repairSensors = false
    end

    if app.formNavigationFields['tool'] then
        if session and session.apiVersion and rfutils.apiVersionCompare("<", {12, 0, 8}) then
            app.formNavigationFields['tool']:enable(false)
        else
            app.formNavigationFields['tool']:enable(true)
        end
    end

    if progressLoader then
        updateProgressLoaderMessage()
        if progressLoaderCounter < 100 then
            progressLoaderCounter = progressLoaderCounter + 5
            progressLoader:value(progressLoaderCounter)
        else
            progressLoader:close()
            app.ui.clearProgressDialog(progressLoader)
            progressLoader = nil
            progressLoaderBaseMessage = nil
            progressLoaderMspStatusLast = nil

            doDiscoverNotify = true

        end
    end

end

local function onToolMenu(self)

    local buttons = {
        {
            label = "@i18n(app.btn_ok)@",
            action = function()

                repairSensors = true
                writePayload = nil
                return true
            end
        }, {label = "@i18n(app.btn_cancel)@", action = function() return true end}
    }

    form.openDialog({width = nil, title = "@i18n(app.modules.validate_sensors.name)@", message = "@i18n(app.modules.validate_sensors.msg_repair)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})

end

local function event(widget, category, value, x, y)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

local function onNavMenu()
    pageRuntime.openMenuContext()
    return true
end

return {reboot = false, eepromWrite = false, minBytes = 0, wakeup = wakeup, refreshswitch = false, simulatorResponse = {}, postLoad = postLoad, postRead = postRead, openPage = openPage, onNavMenu = onNavMenu, event = event, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}, API = {}}
