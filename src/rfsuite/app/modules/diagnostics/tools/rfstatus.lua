--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system
local model = model
local app = rfsuite.app
local tasks = rfsuite.tasks
local rfutils = rfsuite.utils
local session = rfsuite.session

local enableWakeup = false
local lastWakeup = 0

local w, h = lcd.getWindowSize()
local btnW = 100
local btnWs = btnW - (btnW * 20) / 100
local xRight = w - 15

local x, y

local displayPos = {x = xRight - btnW - btnWs - 5 - btnWs, y = app.radio.linePaddingTop, w = 150, h = app.radio.navbuttonHeight}

local IDX_CPULOAD = 0
local IDX_FREERAM = 1
local IDX_BG_TASK = 2
local IDX_RF_MODULE = 3
local IDX_MSP = 4
local IDX_TELEM = 5
local IDX_FBLCONNECTED = 6
local IDX_APIVERSION = 7

local function setStatus(field, ok, dashIfNil)
    if not field then return end
    if dashIfNil and ok == nil then
        field:value("-")
        return
    end
    if ok then
        field:value("@i18n(app.modules.rfstatus.ok)@")
        field:color(GREEN)
    else
        field:value("@i18n(app.modules.rfstatus.error)@")
        field:color(RED)
    end
end

local function addStatusLine(captionText, initialText)

    app.formLines[app.formLineCnt] = form.addLine(captionText)
    app.formFields[app.formFieldCount] = form.addStaticText(app.formLines[app.formLineCnt], displayPos, initialText)
    app.formLineCnt = app.formLineCnt + 1
    app.formFieldCount = app.formFieldCount + 1
end

local function moduleEnabled()
    local m0 = model.getModule(0)
    local m1 = model.getModule(1)
    return (m0 and m0:enable()) or (m1 and m1:enable()) or false
end

local function haveMspSensor()
    local sportSensor = system.getSource({appId = 0xF101})
    local elrsSensor = system.getSource({crsfId = 0x14, subIdStart = 0, subIdEnd = 1})
    return sportSensor or elrsSensor
end

local function openPage(pidx, title, script)
    enableWakeup = false
    app.triggers.closeProgressLoader = true
    form.clear()

    app.lastIdx = pidx
    app.lastTitle = title
    app.lastScript = script

    app.ui.fieldHeader("@i18n(app.modules.diagnostics.name)@" .. " / " .. "@i18n(app.modules.rfstatus.name)@")

    app.formLineCnt = 0
    app.formFieldCount = 0

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    addStatusLine("@i18n(app.modules.fblstatus.cpu_load)@", string.format("%.1f%%", rfsuite.performance.cpuload or 0))

    addStatusLine("@i18n(app.modules.msp_speed.memory_free)@", string.format("%.1f kB", rfsuite.performance.freeram or 0))

    addStatusLine("@i18n(app.modules.rfstatus.bgtask)@", tasks.active() and "@i18n(app.modules.rfstatus.ok)@" or "@i18n(app.modules.rfstatus.error)@")

    addStatusLine("@i18n(app.modules.rfstatus.rfmodule)@", moduleEnabled() and "@i18n(app.modules.rfstatus.ok)@" or "@i18n(app.modules.rfstatus.error)@")

    addStatusLine("@i18n(app.modules.rfstatus.mspsensor)@", haveMspSensor() and "@i18n(app.modules.rfstatus.ok)@" or "@i18n(app.modules.rfstatus.error)@")

    addStatusLine("@i18n(app.modules.rfstatus.telemetrysensors)@", "-")

    addStatusLine("@i18n(app.modules.rfstatus.fblconnected)@", "-")

    addStatusLine("@i18n(app.modules.rfstatus.apiversion)@", "-")

    enableWakeup = true
end

local function postLoad(self) rfutils.log("postLoad", "debug") end
local function postRead(self) rfutils.log("postRead", "debug") end

local function wakeup()
    if not enableWakeup then return end

    local now = os.clock()
    if (now - lastWakeup) < 2 then return end
    lastWakeup = now

    do
        local field = app.formFields and app.formFields[IDX_CPULOAD]
        if field then field:value(string.format("%.1f%%", rfsuite.performance.cpuload or 0)) end
    end

    do
        local field = app.formFields and app.formFields[IDX_FREERAM]
        if field then field:value(string.format("%.1f kB", rfutils.round(rfsuite.performance.freeram or 0, 1))) end
    end

    do
        local field = app.formFields and app.formFields[IDX_BG_TASK]
        local ok = tasks and tasks.active()
        setStatus(field, ok)
    end

    do
        local field = app.formFields and app.formFields[IDX_RF_MODULE]
        setStatus(field, moduleEnabled())
    end

    do
        local field = app.formFields and app.formFields[IDX_MSP]
        setStatus(field, haveMspSensor())
    end

    do
        local field = app.formFields and app.formFields[IDX_TELEM]
        if field then
            local sensors = tasks and tasks.telemetry and tasks.telemetry.validateSensors(false) or false
            if type(sensors) == "table" then

                setStatus(field, #sensors == 0)
            else

                setStatus(field, nil, true)
            end
        end
    end

    do
        local field = app.formFields and app.formFields[IDX_FBLCONNECTED]
        if field then
            local isConnected = session and session.isConnected
            if isConnected then
                setStatus(field, isConnected)
            else
                setStatus(field, nil, true)
            end
        end
    end

    do
        local field = app.formFields and app.formFields[IDX_APIVERSION]
        if field then
            local isInvalid = not session.apiVersionInvalid
            setStatus(field, isInvalid)
        end
    end

end

local function event(widget, category, value, x, y)

    if (category == EVT_CLOSE and value == 0) or value == 35 then
        app.ui.openPage(pageIdx, "@i18n(app.modules.diagnostics.name)@", "diagnostics/diagnostics.lua")
        return true
    end
end

local function onNavMenu()
    app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.FAST)
    app.ui.openPage(pageIdx, "@i18n(app.modules.diagnostics.name)@", "diagnostics/diagnostics.lua")
end

return {reboot = false, eepromWrite = false, minBytes = 0, wakeup = wakeup, refreshswitch = false, simulatorResponse = {}, postLoad = postLoad, postRead = postRead, openPage = openPage, onNavMenu = onNavMenu, event = event, navButtons = {menu = true, save = false, reload = false, tool = false, help = false}, API = {}}
