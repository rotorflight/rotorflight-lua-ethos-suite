--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local app = rfsuite.app
local tasks = rfsuite.tasks
local utils = rfsuite.utils
local session = rfsuite.session
local lcd = lcd
local osClock = os.clock

local state = {
    wakeupEnabled = false,
    pageIdx = nil,
    sensorChoices = {},
    sensorKeys = {},
    sensorNames = {},
    selectedSensorIdx = 1,
    autoScale = true,
    samples = {},
    maxSamples = 180,
    lastValueText = "-",
    lastStateText = "-",
    lastSampleAt = 0,
    samplePeriod = 0.05
}

local function sortSensorListByName(sensorList)
    table.sort(sensorList, function(a, b)
        local an = tostring(a and a.name or ""):lower()
        local bn = tostring(b and b.name or ""):lower()
        return an < bn
    end)
    return sensorList
end

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

local function selectedSensorKey()
    return state.sensorKeys[state.selectedSensorIdx]
end

local function selectedSensorName()
    return state.sensorNames[state.selectedSensorIdx] or "-"
end

local function buildSensorChoices()
    local list = sortSensorListByName(tasks.telemetry.listSensors() or {})

    state.sensorChoices = {}
    state.sensorKeys = {}
    state.sensorNames = {}

    for i, sensor in ipairs(list) do
        state.sensorChoices[#state.sensorChoices + 1] = {sensor.name, i}
        state.sensorKeys[i] = sensor.key
        state.sensorNames[i] = sensor.name
    end

    if #state.sensorChoices == 0 then
        state.sensorChoices[1] = {"-", 1}
        state.sensorKeys[1] = nil
        state.sensorNames[1] = "-"
    end

    if state.selectedSensorIdx < 1 or state.selectedSensorIdx > #state.sensorChoices then
        state.selectedSensorIdx = 1
    end
end

local function addSample(v)
    if type(v) ~= "number" then return end

    state.samples[#state.samples + 1] = v
    while #state.samples > state.maxSamples do
        table.remove(state.samples, 1)
    end
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
    if state.autoScale then
        for i = 1, #state.samples do
            local v = state.samples[i]
            if minV == nil or v < minV then minV = v end
            if maxV == nil or v > maxV then maxV = v end
        end
    else
        minV = -2000
        maxV = 2000
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

    local summary = selectedSensorName() .. "  " .. state.lastValueText
    if state.lastStateText and state.lastStateText ~= "-" then
        summary = summary .. "  " .. state.lastStateText
    end
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

local function openPage(opts)
    state.wakeupEnabled = false
    app.triggers.closeProgressLoader = true

    state.pageIdx = opts.idx
    app.lastIdx = opts.idx
    app.lastTitle = opts.title
    app.lastScript = opts.script

    buildSensorChoices()
    resetSamples()

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.diagnostics.name)@ / FBL Sensors")

    local line = form.addLine("Sensor")
    app.formFields[1] = form.addChoiceField(line, nil, state.sensorChoices, function()
        return state.selectedSensorIdx
    end, function(v)
        state.selectedSensorIdx = tonumber(v) or 1
        resetSamples()
    end)

    line = form.addLine("Auto scale")
    app.formFields[2] = form.addBooleanField(line, nil, function()
        return state.autoScale == true
    end, function(v)
        state.autoScale = (v == true)
    end)

    state.wakeupEnabled = true
end

local function updateSensorState()
    local key = selectedSensorKey()
    if not key then
        state.lastStateText = "-"
        return
    end

    local src = tasks.telemetry.getSensorSource(key)
    local ok = (src ~= nil and src:state() ~= false)
    if ok then
        state.lastStateText = "@i18n(app.modules.validate_sensors.ok)@"
    else
        state.lastStateText = "@i18n(app.modules.validate_sensors.invalid)@"
    end
end

local function sampleSensor()
    local key = selectedSensorKey()
    if not key then
        state.lastValueText = "-"
        return
    end

    local value = tasks.telemetry.getSensor(key)
    if type(value) == "number" then
        addSample(value)
        state.lastValueText = formatValue(value)
    else
        state.lastValueText = "-"
    end
end

local function wakeup()
    if not state.wakeupEnabled then return end
    if not (session and session.telemetryState) then return end

    local now = osClock()
    if (now - state.lastSampleAt) < state.samplePeriod then return end
    state.lastSampleAt = now

    updateSensorState()
    sampleSensor()
    lcd.invalidate()
end

local function onToolMenu()
    resetSamples()
    state.lastValueText = "-"
end

local function event(_, category, value)
    if (category == EVT_CLOSE and value == 0) or value == 35 then
        app.ui.openPage({idx = state.pageIdx, title = "@i18n(app.modules.diagnostics.name)@", script = "diagnostics/diagnostics.lua"})
        return true
    end
end

local function onNavMenu()
    app.ui.progressDisplay(nil, nil, rfsuite.app.loaderSpeed.FAST)
    app.ui.openPage({idx = state.pageIdx, title = "@i18n(app.modules.diagnostics.name)@", script = "diagnostics/diagnostics.lua"})
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
