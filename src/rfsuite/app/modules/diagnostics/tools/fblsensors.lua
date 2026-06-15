--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local pageRuntime = assert(loadfile("app/lib/page_runtime.lua"))()

local app = rfsuite.app
local tasks = rfsuite.tasks
local session = rfsuite.session
local lcd = lcd
local osClock = os.clock
local floor = math.floor

local SOURCES = {
    {label = "@i18n(app.modules.fblsensors.sensor_gyro_x)@", packet = "RAW_IMU", field = "gyro_1", scale = 4 / 16.4},
    {label = "@i18n(app.modules.fblsensors.sensor_gyro_y)@", packet = "RAW_IMU", field = "gyro_2", scale = 4 / 16.4},
    {label = "@i18n(app.modules.fblsensors.sensor_gyro_z)@", packet = "RAW_IMU", field = "gyro_3", scale = 4 / 16.4},
    {label = "@i18n(app.modules.fblsensors.sensor_accel_x)@", packet = "RAW_IMU", field = "accel_1", scale = 1 / 512},
    {label = "@i18n(app.modules.fblsensors.sensor_accel_y)@", packet = "RAW_IMU", field = "accel_2", scale = 1 / 512},
    {label = "@i18n(app.modules.fblsensors.sensor_accel_z)@", packet = "RAW_IMU", field = "accel_3", scale = 1 / 512},
    {label = "@i18n(app.modules.fblsensors.sensor_mag_x)@", packet = "RAW_IMU", field = "mag_1", scale = 1 / 1090},
    {label = "@i18n(app.modules.fblsensors.sensor_mag_y)@", packet = "RAW_IMU", field = "mag_2", scale = 1 / 1090},
    {label = "@i18n(app.modules.fblsensors.sensor_mag_z)@", packet = "RAW_IMU", field = "mag_3", scale = 1 / 1090},
    {label = "@i18n(app.modules.fblsensors.sensor_altitude)@", packet = "ALTITUDE", field = "altitude_cm", scale = 0.01},
    {label = "@i18n(app.modules.fblsensors.sensor_sonar)@", packet = "SONAR", field = "sonar"},
    {label = "@i18n(app.modules.fblsensors.sensor_debug_0)@", packet = "DEBUG", field = "debug_1"},
    {label = "@i18n(app.modules.fblsensors.sensor_debug_1)@", packet = "DEBUG", field = "debug_2"},
    {label = "@i18n(app.modules.fblsensors.sensor_debug_2)@", packet = "DEBUG", field = "debug_3"},
    {label = "@i18n(app.modules.fblsensors.sensor_debug_3)@", packet = "DEBUG", field = "debug_4"},
    {label = "@i18n(app.modules.fblsensors.sensor_debug_4)@", packet = "DEBUG", field = "debug_5"},
    {label = "@i18n(app.modules.fblsensors.sensor_debug_5)@", packet = "DEBUG", field = "debug_6"},
    {label = "@i18n(app.modules.fblsensors.sensor_debug_6)@", packet = "DEBUG", field = "debug_7"},
    {label = "@i18n(app.modules.fblsensors.sensor_debug_7)@", packet = "DEBUG", field = "debug_8"},
}

local state = {
    wakeupEnabled = false,
    pageIdx = nil,
    sourceChoices = {},
    selectedSourceIdx = 1,
    samples = {},
    maxSamples = 180,
    lastValueText = "-",
    lastStateText = "WAIT",
    lastSampleAt = 0,
    samplePeriod = 0.08,
    pending = nil,
    pendingData = nil,
    pendingAt = 0,
    pendingTimeout = 1.0,
    pollingEnabled = false,
    apis = nil,
}

local function resetSamples()
    state.samples = {}
    state.lastValueText = "-"
end

local function formatValue(v)
    local value = tonumber(v)
    if not value then return "-" end
    local abs = math.abs(value)
    if abs >= 100 then
        return string.format("%.1f", value)
    end
    return string.format("%.2f", value)
end

local function selectedSource()
    return SOURCES[state.selectedSourceIdx]
end

local function selectedSourceName()
    local s = selectedSource()
    return (s and s.label) or "-"
end

local function buildSourceChoices()
    state.sourceChoices = {}
    for i, src in ipairs(SOURCES) do
        state.sourceChoices[#state.sourceChoices + 1] = {src.label, i}
    end
end

local function addSample(v)
    if type(v) ~= "number" then return end

    state.samples[#state.samples + 1] = v
    while #state.samples > state.maxSamples do
        table.remove(state.samples, 1)
    end
end

local function readSelectedValue()
    local src = selectedSource()
    if not src then return nil end

    local apis = state.apis
    local api = apis and apis[src.packet]
    if not api then return nil end

    local value = api.readValue(src.field)
    if type(value) ~= "number" then return nil end
    if src.scale then return value * src.scale end

    return value
end

local function drawGraph()
    local lcdW, lcdH = lcd.getWindowSize()

    local gx = 0
    local gy = math.floor(form.height() + 2)
    local gw = lcdW - 1
    local gh = lcdH - gy - 2
    if gh < 30 then return end

    local pad = 6
    local px = gx + pad
    local py = gy + pad
    local pw = gw - (pad * 2)
    local ph = gh - (pad * 2)
    if pw < 20 or ph < 20 then return end

    local minV, maxV
    for i = 1, #state.samples do
        local v = state.samples[i]
        if minV == nil or v < minV then minV = v end
        if maxV == nil or v > maxV then maxV = v end
    end

    if minV == nil or maxV == nil then
        minV = -1
        maxV = 1
    end
    if minV == maxV then
        minV = minV - 1
        maxV = maxV + 1
    end

    local isDark = lcd.darkMode()

    local summary = selectedSourceName() .. "  " .. state.lastValueText .. "  " .. state.lastStateText
    lcd.color(isDark and lcd.RGB(230, 230, 230) or lcd.RGB(20, 20, 20))
    lcd.drawText(px, py - 2, summary, LEFT)

    lcd.color(isDark and lcd.GREY(80) or lcd.GREY(180))
    for i = 0, 4 do
        local y = py + math.floor((ph * i) / 4 + 0.5)
        lcd.drawLine(px, y, px + pw, y)
    end

    local n = #state.samples
    if n < 2 then return end

    lcd.color(isDark and lcd.RGB(255, 255, 255) or lcd.RGB(0, 0, 0))
    local prevX, prevY
    for i = 1, n do
        local x = px + math.floor(((i - 1) * pw) / math.max(1, n - 1) + 0.5)
        local norm = (state.samples[i] - minV) / (maxV - minV)
        local y = py + ph - math.floor(norm * ph + 0.5)

        if prevX and prevY then
            lcd.drawLine(prevX, prevY, x, y)
        end

        prevX, prevY = x, y
    end

    lcd.color(isDark and lcd.RGB(255, 200, 0) or lcd.RGB(0, 120, 255))
    lcd.drawFilledCircle(prevX, prevY, 2)
end

local function paint()
    drawGraph()
end

local function loadApis()
    if state.apis then return true end

    local apiLoader = tasks.msp and tasks.msp.api
    if not apiLoader then return false end

    local apis = {
        RAW_IMU = apiLoader.loadPage("RAW_IMU"),
        ALTITUDE = apiLoader.loadPage("ALTITUDE"),
        SONAR = apiLoader.loadPage("SONAR"),
        DEBUG = apiLoader.loadPage("DEBUG")
    }

    for name, api in pairs(apis) do
        if not api then return false end
        if api.enableDeltaCache then api.enableDeltaCache(false) end
        if api.setUUID then api.setUUID("fblsensors." .. name) end
        if api.setErrorHandler then
            api.setErrorHandler(function()
                -- Clear the pending flag immediately so a single dropped/errored
                -- reply doesn't stall sampling until pendingTimeout.
                if state.pending == name then
                    state.pending = nil
                    state.pendingData = nil
                    state.lastStateText = "INVALID"
                end
            end)
        end
    end

    state.apis = apis
    return true
end

local function updatePendingState()
    local pending = state.pending
    if pending == nil then return end

    local api = state.apis and state.apis[pending]
    if api and api.data and api.data() ~= state.pendingData then
        state.pending = nil
        state.pendingData = nil
        state.lastStateText = "OK"
        return
    end

    if (osClock() - state.pendingAt) > state.pendingTimeout then
        state.pending = nil
        state.pendingData = nil
        state.lastStateText = "INVALID"
    end
end

local function queueRead(apiname)
    if state.pending ~= nil then return false end
    if not loadApis() then
        state.lastStateText = "INVALID"
        return false
    end

    local api = state.apis and state.apis[apiname]
    if not api then return false end

    state.pendingData = api.data and api.data() or nil
    state.pending = apiname
    state.pendingAt = osClock()

    local ok = api.read()
    if not ok then
        state.pending = nil
        state.pendingData = nil
        state.lastStateText = "INVALID"
    end

    return ok
end

local function requestSelectedPacket()
    local src = selectedSource()
    if not src then return end
    queueRead(src.packet)
end

local function openPage(opts)
    state.wakeupEnabled = false
    app.triggers.closeProgressLoader = true

    state.pageIdx = opts.idx
    app.lastIdx = opts.idx
    app.lastTitle = opts.title
    app.lastScript = opts.script

    buildSourceChoices()
    resetSamples()
    state.lastStateText = "WAIT"
    state.pollingEnabled = false

    if app.formFields then for k in pairs(app.formFields) do app.formFields[k] = nil end end
    if app.formLines then for k in pairs(app.formLines) do app.formLines[k] = nil end end

    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.diagnostics.name)@ / @i18n(app.modules.fblsensors.name)@")

    local line = form.addLine("@i18n(app.modules.fblsensors.source)@")
    app.formFields[1] = form.addChoiceField(line, nil, state.sourceChoices, function()
        return state.selectedSourceIdx
    end, function(v)
        state.selectedSourceIdx = tonumber(v) or 1
        state.lastStateText = "WAIT"
        state.pending = nil
        state.pendingData = nil
        resetSamples()
    end)

    state.wakeupEnabled = true
end

local function wakeup()
    if not state.wakeupEnabled then return end
    if not (session and session.telemetryState) then return end

    -- Don't start MSP polling until the page loader has fully closed.
    if not state.pollingEnabled then
        if app.dialogs and app.dialogs.progressDisplay then
            return
        end
        state.pollingEnabled = true
        state.lastSampleAt = 0
    end

    local now = osClock()

    updatePendingState()

    if (now - state.lastSampleAt) < state.samplePeriod then return end
    state.lastSampleAt = now

    if tasks.msp.mspQueue:isProcessed() and state.pending == nil then
        requestSelectedPacket()
    end

    local value = readSelectedValue()
    if type(value) == "number" then
        addSample(value)
        state.lastValueText = formatValue(value)
    else
        state.lastValueText = "-"
    end

    lcd.invalidate()
end

local function onToolMenu()
    resetSamples()
    state.lastStateText = "WAIT"
end

local onNavMenu

local function event(_, category, value)
    return pageRuntime.handleCloseEvent(category, value, {onClose = onNavMenu})
end

function onNavMenu()
    state.pending = nil
    state.pendingData = nil
    state.apis = nil
    pageRuntime.openMenuContext()
    return true
end

return {
    reboot = false,
    eepromWrite = false,
    wakeup = wakeup,
    openPage = openPage,
    onNavMenu = onNavMenu,
    onToolMenu = onToolMenu,
    event = event,
    paint = paint,
    navButtons = {menu = true, save = false, reload = false, tool = true, help = false},
    API = {}
}
