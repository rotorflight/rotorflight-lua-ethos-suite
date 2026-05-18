--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()
local elrsTask = assert(loadfile("app/modules/diagnostics/tools/elrslink_task.lua"))()

local app = rfsuite.app
local session = rfsuite.session
local math_floor = math.floor
local math_max = math.max
local os_clock = os.clock
local tostring = tostring
local type = type

local enableWakeup = false
local lastRefreshAt = 0
local fields = {}
local fieldCache = {}
local buttonCache = {}
local T = {
    title = "@i18n(app.modules.elrs_telemetry.name)@",
    status = "@i18n(app.modules.elrs_telemetry.status)@",
    rotorflight = "@i18n(app.modules.elrs_telemetry.rotorflight)@",
    elrsModule = "@i18n(app.modules.elrs_telemetry.elrs_module)@",
    action = "@i18n(app.modules.elrs_telemetry.action)@",
    actions = "@i18n(app.modules.elrs_telemetry.actions)@",
    probe = "@i18n(app.modules.elrs_telemetry.action_probe)@",
    probeOnly = "@i18n(app.modules.elrs_telemetry.action_probe_only)@",
    rfToElrs = "@i18n(app.modules.elrs_telemetry.action_rf_to_elrs)@",
    elrsToRf = "@i18n(app.modules.elrs_telemetry.action_elrs_to_rf)@",
    connectFirst = "@i18n(app.modules.elrs_telemetry.status_connect_first)@",
    requiresCrsf = "@i18n(app.modules.elrs_telemetry.status_requires_crsf)@",
    waitingTelemetryConfig = "@i18n(app.modules.elrs_telemetry.status_waiting_telemetry_config)@",
    notProbed = "@i18n(app.modules.elrs_telemetry.status_not_probed)@",
    modeNative = "@i18n(app.modules.elrs_telemetry.mode_native)@",
    modeCustom = "@i18n(app.modules.elrs_telemetry.mode_custom)@"
}

local screenW = lcd.getWindowSize()
local valueX = math_max(120, math_floor(screenW * 0.30))
local valuePos = {x = valueX, y = app.radio.linePaddingTop, w = screenW - valueX - 8, h = app.radio.navbuttonHeight}

local function telemetryModeLabel(mode)
    if mode == 0 then return T.modeNative end
    if mode == 1 then return T.modeCustom end
    return tostring(mode or "?")
end

local function actionModeLabel(mode)
    if mode == elrsTask.MODE_ROTORFLIGHT_TO_ELRS then
        return T.rfToElrs
    end
    if mode == elrsTask.MODE_ELRS_TO_ROTORFLIGHT then
        return T.elrsToRf
    end
    return T.probeOnly
end

local function setFieldValue(key, value)
    if fieldCache[key] == value then return end
    fieldCache[key] = value

    local field = fields[key]
    if field then field:value(value or "-") end
end

local function setButtonEnabled(key, enabled)
    if buttonCache[key] == enabled then return end
    buttonCache[key] = enabled

    local field = fields[key]
    if field and field.enable then
        field:enable(enabled)
    end
end

local function formatRotorflightSummary()
    local fcConfig = session and session.crsfTelemetryConfig
    if not session or session.isConnected ~= true then
        return T.connectFirst
    end
    if session.telemetryType ~= "crsf" then
        return T.requiresCrsf
    end
    if type(fcConfig) ~= "table" then
        return T.waitingTelemetryConfig
    end

    return "mode="
        .. telemetryModeLabel(fcConfig.mode)
        .. ", rate="
        .. tostring(fcConfig.linkRate)
        .. ", ratio=1:"
        .. tostring(fcConfig.linkRatio)
end

local function formatElrsSummary()
    local linkConfig = session and session.elrsLinkConfig
    if type(linkConfig) ~= "table" then
        return T.notProbed
    end

    local rateText = linkConfig.packetRateLabel or (linkConfig.packetRate and (tostring(linkConfig.packetRate) .. "Hz")) or "?"
    local ratioText = linkConfig.telemetryRatioLabel or "?"
    local effectiveRatio = linkConfig.telemetryRatioEffective

    if effectiveRatio and ratioText ~= ("1:" .. tostring(effectiveRatio)) then
        ratioText = ratioText .. " (effective 1:" .. tostring(effectiveRatio) .. ")"
    end

    return "rate=" .. tostring(rateText) .. ", ratio=" .. tostring(ratioText)
end

local function updateDisplay(force)
    if not force then
        local now = os_clock()
        if (now - lastRefreshAt) < 0.2 then return end
        lastRefreshAt = now
    else
        lastRefreshAt = os_clock()
    end

    setFieldValue("status", elrsTask.getStatus())
    setFieldValue("rotorflight", formatRotorflightSummary())
    setFieldValue("elrs", formatElrsSummary())
    setFieldValue("action", actionModeLabel(elrsTask.getMode()))

    local buttonsEnabled = not elrsTask.isRunning()
    setButtonEnabled("probe", buttonsEnabled)
    setButtonEnabled("rf_to_elrs", buttonsEnabled)
    setButtonEnabled("elrs_to_rf", buttonsEnabled)
end

local function startAction(mode)
    elrsTask.start(mode)
    updateDisplay(true)
end

local function pressProbe()
    startAction(elrsTask.MODE_PROBE)
end

local function pressRotorflightToElrs()
    startAction(elrsTask.MODE_ROTORFLIGHT_TO_ELRS)
end

local function pressElrsToRotorflight()
    startAction(elrsTask.MODE_ELRS_TO_ROTORFLIGHT)
end

local function addLine(key, label, initial)
    app.formLines[app.formLineCnt] = form.addLine(label)
    fields[key] = form.addStaticText(app.formLines[app.formLineCnt], valuePos, initial or "-")
    app.formLineCnt = app.formLineCnt + 1
end

local function addButtons()
    local line = form.addLine("", nil, false)
    local gap = app.radio.buttonPaddingSmall or 6
    local sidePadding = app.radio.buttonPadding or gap
    local rowY = app.radio.linePaddingTop
    local availableW = app.lcdWidth - sidePadding - (gap * 4)
    local buttonW = math_floor(availableW / 3)
    local x1 = sidePadding
    local x2 = x1 + buttonW + gap
    local x3 = x2 + buttonW + gap

    fields.probe = form.addButton(line, {x = x1, y = rowY, w = buttonW, h = app.radio.navbuttonHeight}, {
        text = T.probe,
        options = FONT_S,
        press = pressProbe
    })
    fields.rf_to_elrs = form.addButton(line, {x = x2, y = rowY, w = buttonW, h = app.radio.navbuttonHeight}, {
        text = T.rfToElrs,
        options = FONT_S,
        press = pressRotorflightToElrs
    })
    fields.elrs_to_rf = form.addButton(line, {x = x3, y = rowY, w = buttonW, h = app.radio.navbuttonHeight}, {
        text = T.elrsToRf,
        options = FONT_S,
        press = pressElrsToRotorflight
    })

    app.formLineCnt = app.formLineCnt + 1
end

local function openPage(opts)
    enableWakeup = false
    form.clear()
    app.triggers.closeProgressLoader = true
    app.lastIdx = opts.idx
    app.lastTitle = opts.title
    app.lastScript = opts.script

    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end
    for k in pairs(fields) do fields[k] = nil end
    for k in pairs(fieldCache) do fieldCache[k] = nil end
    for k in pairs(buttonCache) do buttonCache[k] = nil end

    elrsTask.reset()
    lastRefreshAt = 0

    app.ui.fieldHeader("@i18n(app.modules.diagnostics.name)@ / " .. T.title)
    app.formLineCnt = 0

    addLine("status", T.status, elrsTask.getStatus())
    addLine("rotorflight", T.rotorflight, formatRotorflightSummary())
    addLine("elrs", T.elrsModule, formatElrsSummary())
    addLine("action", T.action, actionModeLabel(elrsTask.getMode()))
    addButtons()

    enableWakeup = true
    updateDisplay(true)
end

local function wakeup()
    if not enableWakeup then return end
    if elrsTask.isRunning() then
        elrsTask.wakeup()
    end
    updateDisplay(false)
end

local function onNavMenu()
    enableWakeup = false
    elrsTask.reset()
    pageRuntime.openMenuContext()
    return true
end

local function event(widget, category, value)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

return {
    openPage = openPage,
    wakeup = wakeup,
    event = event,
    onNavMenu = onNavMenu,
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    API = {}
}
