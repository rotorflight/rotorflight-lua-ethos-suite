--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local fields = {}
local labels = {}

local enableWakeup = false

local w, h = lcd.getWindowSize()
local buttonW = 100
local buttonWs = buttonW - (buttonW * 20) / 100
local x = w - 15

local displayPos = {x = x - buttonW - buttonWs - 5 - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 100, h = rfsuite.app.radio.navbuttonHeight}

local invalidSensors = rfsuite.tasks.telemetry.validateSensors()

local repairSensors = false

local sensorTlm = nil

local progressLoader
local progressLoaderCounter = 0
local progressLoaderBaseMessage
local progressLoaderMspStatusLast
local doDiscoverNotify = false

local function sortSensorListByName(sensorList)
    table.sort(sensorList, function(a, b) return a.name:lower() < b.name:lower() end)
    return sensorList
end

local sensorList = sortSensorListByName(rfsuite.tasks.telemetry.listSensors())

local function openPage(pidx, title, script)
    enableWakeup = false
    rfsuite.app.triggers.closeProgressLoader = true

    form.clear()

    rfsuite.app.lastIdx = pidx
    rfsuite.app.lastTitle = title
    rfsuite.app.lastScript = script

    rfsuite.app.ui.fieldHeader("@i18n(app.modules.diagnostics.name)@" .. " / " .. "@i18n(app.modules.validate_sensors.name)@")

    rfsuite.app.formLineCnt = 0

    local app = rfsuite.app
    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    local posText = {x = x - 5 - buttonW - buttonWs, y = rfsuite.app.radio.linePaddingTop, w = 200, h = rfsuite.app.radio.navbuttonHeight}
    for i, v in ipairs(sensorList or {}) do
        rfsuite.app.formLineCnt = rfsuite.app.formLineCnt + 1
        rfsuite.app.formLines[rfsuite.app.formLineCnt] = form.addLine(v.name)
        rfsuite.app.formFields[v.key] = form.addStaticText(rfsuite.app.formLines[rfsuite.app.formLineCnt], posText, "-")
    end

    enableWakeup = true
end

local function sensorKeyExists(searchKey, sensorTable)
    if type(sensorTable) ~= "table" then return false end

    for _, sensor in pairs(sensorTable) do if sensor['key'] == searchKey then return true end end

    return false
end

local function postLoad(self) rfsuite.utils.log("postLoad", "debug") end

local function postRead(self) rfsuite.utils.log("postRead", "debug") end

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

end

local function runRepair(data)

    local sensorList = rfsuite.tasks.telemetry.listSensors()
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

    local WRITEAPI = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
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
    local showMsp = rfsuite.preferences and rfsuite.preferences.general and rfsuite.preferences.general.mspstatusdialog
    local mspStatus = (showMsp and rfsuite.session and rfsuite.session.mspStatusMessage) or nil
    if mspStatus and mspStatus ~= progressLoaderMspStatusLast then
        if #mspStatus > 32 then mspStatus = string.sub(mspStatus, 1, 29) .. "..." end
        progressLoader:message(progressLoaderBaseMessage .. " [" .. mspStatus .. "]")
        progressLoaderMspStatusLast = mspStatus
    elseif not mspStatus and progressLoaderMspStatusLast then
        progressLoader:message(progressLoaderBaseMessage)
        progressLoaderMspStatusLast = nil
    end
end

local function wakeup()

    if enableWakeup == false then return end

    if doDiscoverNotify == true then

        if not sensorTlm then
            if not rfsuite.session.telemetrySensor then return false end

            sensorTlm = sport.getSensor()
            sensorTlm:module(rfsuite.session.telemetrySensor:module())

            if not sensorTlm then return false end
        end

        doDiscoverNotify = false

        local buttons = {{label = "@i18n(app.btn_ok)@", action = function() return true end}}

        if rfsuite.utils.ethosVersionAtLeast({1, 6, 3}) then
            rfsuite.utils.log("Starting discover sensors", "info")
            sensorTlm:discover()
        else
            form.openDialog({width = nil, title = "@i18n(app.modules.validate_sensors.name)@", message = "@i18n(app.modules.validate_sensors.msg_repair_fin)@", buttons = buttons, wakeup = function() end, paint = function() end, options = TEXT_LEFT})
        end
    end

    invalidSensors = rfsuite.tasks.telemetry.validateSensors()

    for i, v in ipairs(sensorList) do

        local field = rfsuite.app.formFields and rfsuite.app.formFields[v.key]
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

        progressLoader = form.openProgressDialog("@i18n(app.msg_saving)@", "@i18n(app.msg_saving_to_fbl)@")
        progressLoader:closeAllowed(false)
        progressLoaderCounter = 0
        progressLoaderBaseMessage = "@i18n(app.msg_saving_to_fbl)@"
        progressLoaderMspStatusLast = nil
        updateProgressLoaderMessage()
        rfsuite.app.ui.registerProgressDialog(progressLoader, progressLoaderBaseMessage)

        API = rfsuite.tasks.msp.api.load("TELEMETRY_CONFIG")
        API.setUUID("550e8400-e29b-41d4-a716-446655440000")
        API.setCompleteHandler(function(self, buf)
            local data = API.data()
            if data['parsed'] then runRepair(data) end
        end)
        API.read()
        repairSensors = false
    end

    if rfsuite.app.formNavigationFields['tool'] then
        if rfsuite.session and rfsuite.session.apiVersion and rfsuite.utils.apiVersionCompare("<", "12.08") then
            rfsuite.app.formNavigationFields['tool']:enable(false)
        else
            rfsuite.app.formNavigationFields['tool']:enable(true)
        end
    end

    if progressLoader then
        updateProgressLoaderMessage()
        if progressLoaderCounter < 100 then
            progressLoaderCounter = progressLoaderCounter + 5
            progressLoader:value(progressLoaderCounter)
        else
            progressLoader:close()
            rfsuite.app.ui.clearProgressDialog(progressLoader)
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

    if category == EVT_CLOSE and value == 0 or value == 35 then
        rfsuite.app.ui.openPage(pageIdx, "@i18n(app.modules.diagnostics.name)@", "diagnostics/diagnostics.lua")
        return true
    end
end

local function onNavMenu()
    rfsuite.app.ui.progressDisplay(nil, nil, true)
    rfsuite.app.ui.openPage(pageIdx, "@i18n(app.modules.diagnostics.name)@", "diagnostics/diagnostics.lua")
end

return {reboot = false, eepromWrite = false, minBytes = 0, wakeup = wakeup, refreshswitch = false, simulatorResponse = {}, postLoad = postLoad, postRead = postRead, openPage = openPage, onNavMenu = onNavMenu, event = event, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}, API = {}}
