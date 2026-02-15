--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local app = rfsuite.app
local tasks = rfsuite.tasks
local session = rfsuite.session
local lcd = lcd
local osClock = os.clock
local sin = math.sin
local floor = math.floor

local MSP_RAW_IMU = 102
local MSP_ALTITUDE = 109
local MSP_SONAR = 58
local MSP_DEBUG = 254

local SOURCES = {
    {label = "Gyro X", packet = "raw_imu", group = "gyro", idx = 1},
    {label = "Gyro Y", packet = "raw_imu", group = "gyro", idx = 2},
    {label = "Gyro Z", packet = "raw_imu", group = "gyro", idx = 3},
    {label = "Accel X", packet = "raw_imu", group = "accel", idx = 1},
    {label = "Accel Y", packet = "raw_imu", group = "accel", idx = 2},
    {label = "Accel Z", packet = "raw_imu", group = "accel", idx = 3},
    {label = "Mag X", packet = "raw_imu", group = "mag", idx = 1},
    {label = "Mag Y", packet = "raw_imu", group = "mag", idx = 2},
    {label = "Mag Z", packet = "raw_imu", group = "mag", idx = 3},
    {label = "Altitude", packet = "altitude"},
    {label = "Sonar", packet = "sonar"},
    {label = "Debug 0", packet = "debug", idx = 1},
    {label = "Debug 1", packet = "debug", idx = 2},
    {label = "Debug 2", packet = "debug", idx = 3},
    {label = "Debug 3", packet = "debug", idx = 4},
    {label = "Debug 4", packet = "debug", idx = 5},
    {label = "Debug 5", packet = "debug", idx = 6},
    {label = "Debug 6", packet = "debug", idx = 7},
    {label = "Debug 7", packet = "debug", idx = 8},
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
    pendingAt = 0,
    pendingTimeout = 1.0,
    pollingEnabled = false,
    rawImu = nil,
    altitude = nil,
    sonar = nil,
    debug = nil,
}

local function writeS16(v)
    if v < 0 then v = v + 0x10000 end
    return v % 256, floor(v / 256) % 256
end

local function writeS32(v)
    if v < 0 then v = v + 0x100000000 end
    return v % 256, floor(v / 256) % 256, floor(v / 65536) % 256, floor(v / 16777216) % 256
end

local function getRawImuSimResponse()
    local t = osClock() * 3.5

    local ax = math.floor(sin(t) * 180)
    local ay = math.floor(sin(t + 1.3) * 160)
    local az = math.floor(512 + sin(t + 0.4) * 70)

    local gx = math.floor(sin(t * 1.2) * 220)
    local gy = math.floor(sin(t * 1.1 + 1.1) * 200)
    local gz = math.floor(sin(t * 0.9 + 2.0) * 170)

    local mx = math.floor(sin(t * 0.8) * 120)
    local my = math.floor(sin(t * 0.7 + 0.7) * 140)
    local mz = math.floor(sin(t * 0.6 + 1.8) * 90)

    local b = {}
    local function push16(v)
        local l, h = writeS16(v)
        b[#b + 1] = l
        b[#b + 1] = h
    end

    push16(ax)
    push16(ay)
    push16(az)
    push16(gx)
    push16(gy)
    push16(gz)
    push16(mx)
    push16(my)
    push16(mz)

    return b
end

local function getAltitudeSimResponse()
    local t = osClock() * 1.2
    local altitudeCm = math.floor((100 + sin(t) * 40) * 100)
    local b0, b1, b2, b3 = writeS32(altitudeCm)
    return {b0, b1, b2, b3}
end

local function getSonarSimResponse()
    local t = osClock() * 1.5
    local sonar = math.floor(120 + sin(t) * 30)
    local b0, b1, b2, b3 = writeS32(sonar)
    return {b0, b1, b2, b3}
end

local function getDebugSimResponse()
    local t = osClock() * 2.0
    local b = {}
    local function push32(v)
        local b0, b1, b2, b3 = writeS32(v)
        b[#b + 1] = b0
        b[#b + 1] = b1
        b[#b + 1] = b2
        b[#b + 1] = b3
    end

    for i = 1, 8 do
        push32(math.floor(sin(t + i * 0.6) * 1000))
    end

    return b
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

local function parseRawImu(buf)
    local m = tasks.msp.mspHelper

    local ax = m.readS16(buf)
    local ay = m.readS16(buf)
    local az = m.readS16(buf)

    local gx = m.readS16(buf)
    local gy = m.readS16(buf)
    local gz = m.readS16(buf)

    local mx = m.readS16(buf)
    local my = m.readS16(buf)
    local mz = m.readS16(buf)

    if not mz then return false end

    state.rawImu = {
        accel = {ax / 512, ay / 512, az / 512},
        gyro = {gx * (4 / 16.4), gy * (4 / 16.4), gz * (4 / 16.4)},
        mag = {mx / 1090, my / 1090, mz / 1090}
    }

    return true
end

local function parseAltitude(buf)
    local m = tasks.msp.mspHelper
    local v = m.readS32(buf)
    if v == nil then return false end
    state.altitude = v / 100
    return true
end

local function parseSonar(buf)
    local m = tasks.msp.mspHelper
    local v = m.readS32(buf)
    if v == nil then return false end
    state.sonar = v
    return true
end

local function parseDebug(buf)
    local m = tasks.msp.mspHelper
    local d = {}
    for i = 1, 8 do
        d[i] = m.readS32(buf)
        if d[i] == nil then return false end
    end
    state.debug = d
    return true
end

local function readSelectedValue()
    local src = selectedSource()
    if not src then return nil end

    if src.packet == "raw_imu" and state.rawImu then
        local group = state.rawImu[src.group]
        return group and group[src.idx] or nil
    end

    if src.packet == "altitude" then return state.altitude end
    if src.packet == "sonar" then return state.sonar end
    if src.packet == "debug" and state.debug then return state.debug[src.idx] end

    return nil
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

local function queueRead(command, apiname, parser, simulatorResponse)
    if state.pending ~= nil then return false end

    state.pending = apiname
    state.pendingAt = osClock()

    return tasks.msp.mspQueue:add({
        command = command,
        apiname = apiname,
        uuid = "fblsensors." .. apiname,
        processReply = function(self, buf)
            local ok = parser(buf)
            state.pending = nil
            state.lastStateText = ok and "OK" or "INVALID"
        end,
        errorHandler = function()
            state.pending = nil
            state.lastStateText = "INVALID"
        end,
        simulatorResponse = simulatorResponse
    })
end

local function requestSelectedPacket()
    local src = selectedSource()
    if not src then return end

    if src.packet == "raw_imu" then
        queueRead(MSP_RAW_IMU, "RAW_IMU", parseRawImu, getRawImuSimResponse())
        return
    end

    if src.packet == "altitude" then
        queueRead(MSP_ALTITUDE, "ALTITUDE", parseAltitude, getAltitudeSimResponse())
        return
    end

    if src.packet == "sonar" then
        queueRead(MSP_SONAR, "SONAR", parseSonar, getSonarSimResponse())
        return
    end

    if src.packet == "debug" then
        queueRead(MSP_DEBUG, "DEBUG", parseDebug, getDebugSimResponse())
        return
    end
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

    if app.formFields then for i = 1, #app.formFields do app.formFields[i] = nil end end
    if app.formLines then for i = 1, #app.formLines do app.formLines[i] = nil end end

    form.clear()
    app.ui.fieldHeader("@i18n(app.modules.diagnostics.name)@ / FBL Sensors")

    local line = form.addLine("Source")
    app.formFields[1] = form.addChoiceField(line, nil, state.sourceChoices, function()
        return state.selectedSourceIdx
    end, function(v)
        state.selectedSourceIdx = tonumber(v) or 1
        state.lastStateText = "WAIT"
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

    if state.pending ~= nil and (now - state.pendingAt) > state.pendingTimeout then
        state.pending = nil
        state.lastStateText = "INVALID"
    end

    if (now - state.lastSampleAt) < state.samplePeriod then return end
    state.lastSampleAt = now

    if tasks.msp.mspQueue:isProcessed() then
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
