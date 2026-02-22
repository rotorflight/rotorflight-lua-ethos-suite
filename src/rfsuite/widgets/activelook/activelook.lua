--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activelook = {}

local os_clock = os.clock
local floor = math.floor
local format = string.format

local REDRAW_INTERVAL = 0.05
local TOP_PADDING = 10
local SIDE_PADDING = 10
local ICON_SIZE = 28
local ICON_GAP = 20
local TEXT_Y_OFFSET = 5

local ICONS = {
    current = 19, -- power
    voltage = 21, -- power-avg
    fuel = 1, -- battery-low
    timer = 8 -- chrono
}

local MODE_ROWS = {
    preflight = {"CURRENT:", "VOLTAGE:", "FUEL:", "TIMER:"},
    inflight = {"CURRENT:", "VOLTAGE:", "FUEL:", "TIMER:"},
    postflight = {"CURRENT:", "VOLTAGE:", "FUEL:", "TIMER:"}
}

local function getMode()
    local mode = rfsuite.flightmode and rfsuite.flightmode.current
    if mode == "preflight" or mode == "inflight" or mode == "postflight" then
        return mode
    end
    return "preflight"
end

local function getSensor(name)
    local telemetry = rfsuite.tasks and rfsuite.tasks.telemetry
    local getter = telemetry and telemetry.getSensor
    if not getter then return nil end
    return getter(name)
end

local function toNumber(value)
    if type(value) == "number" then return value end
    if type(value) ~= "string" then return nil end
    local token = value:match("([+-]?%d*%.?%d+)")
    if token then return tonumber(token) end
    return nil
end

local function formatNumber(value, decimals, suffix)
    if type(value) ~= "number" then return "-" end
    local text
    if decimals == 1 then
        text = format("%.1f", value)
    elseif decimals == 0 then
        text = tostring(floor(value + 0.5))
    else
        text = tostring(value)
    end
    if suffix and suffix ~= "" then
        text = text .. suffix
    end
    return text
end

local function formatDuration(seconds)
    local value = toNumber(seconds)
    if type(value) ~= "number" or value < 0 then return "00:00" end
    local total = floor(value + 0.5)
    local mins = floor(total / 60)
    local secs = total % 60
    return format("%02d:%02d", mins, secs)
end

local function readTimer(context, mode, now)
    local timer = rfsuite.session and rfsuite.session.timer
    if mode == "inflight" then
        if timer and type(timer.live) == "number" then return timer.live end
        if context.inflightStart then return now - context.inflightStart end
    end
    if mode == "postflight" then
        if timer and type(timer.session) == "number" and timer.session > 0 then return timer.session end
    end
    return context.lastFlightSeconds or 0
end

local function updateStats(context, mode, now)
    if mode == "inflight" and not context.inflight then
        context.inflight = true
        context.inflightStart = now
    elseif mode ~= "inflight" and context.inflight then
        context.inflight = false
        context.inflightStart = nil
    end
    context.lastFlightSeconds = readTimer(context, mode, now)
end

local function buildLines(context, mode, now)
    local current = toNumber(getSensor("current"))
    local voltage = toNumber(getSensor("voltage"))
    local fuel = toNumber(getSensor("smartfuel"))
    updateStats(context, mode, now)

    return {
        formatNumber(current, 1, "A"),
        formatNumber(voltage, 1, "V"),
        formatNumber(fuel, 0, "%"),
        formatDuration(context.lastFlightSeconds)
    }
end

local function create()
    return {
        layout = nil,
        lastDraw = 0,
        lastMode = nil,
        lastValues = {},
        inflight = false,
        inflightStart = nil,
        lastFlightSeconds = 0
    }
end

local function pickFont(lineHeight)
    if lineHeight >= 26 then return 2 end
    return 1
end

local function build(context)
    local w, h = glasses.getWindowSize()
    context.layout = glasses.createLayout({
        x = SIDE_PADDING,
        y = TOP_PADDING,
        w = w - (SIDE_PADDING * 2),
        h = h - (TOP_PADDING * 2),
        text = {x = 0, y = 0, font = 1},
        border = false
    })
    context.w = w
    context.h = h
end

local function needsRedraw(context, mode, values)
    if mode ~= context.lastMode then return true end
    for i = 1, #values do
        if values[i] ~= context.lastValues[i] then return true end
    end
    return false
end

local function render(context, mode, values)
    local labels = MODE_ROWS[mode]
    local commands = {}
    local lineCount = #labels
    local contentH = (context.h or 0) - (TOP_PADDING * 2)
    if contentH < 1 then contentH = 1 end
    local step = floor(contentH / lineCount)
    if step < 14 then step = 14 end
    local font = pickFont(step)
    local y = 0
    local textX = ICON_SIZE + ICON_GAP

    for i = 1, #labels do
        local value = values[i] or "-"
        local iconId
        if i == 1 then iconId = ICONS.current
        elseif i == 2 then iconId = ICONS.voltage
        elseif i == 3 then iconId = ICONS.fuel
        elseif i == 4 then iconId = ICONS.timer
        end
        if iconId then
            commands[#commands + 1] = {bitmap = {id = iconId, x = 0, y = y}}
        end
        commands[#commands + 1] = {text = {text = value, x = textX, y = y + TEXT_Y_OFFSET, font = font}}
        y = y + step
    end

    context.layout:clearAndDisplayExtended({
        x = 0,
        y = 0,
        text = "",
        commands = commands
    })

    context.lastMode = mode
    for i = 1, #values do
        context.lastValues[i] = values[i]
    end
end

local function wakeup(context)
    if not context.layout then build(context) end
    local now = os_clock()
    if (now - (context.lastDraw or 0)) < REDRAW_INTERVAL then return end
    context.lastDraw = now

    local mode = getMode()
    local values = buildLines(context, mode, now)
    if needsRedraw(context, mode, values) then
        render(context, mode, values)
    end
end

function activelook.create()
    return create()
end

function activelook.build(widget)
    build(widget)
end

function activelook.wakeup(widget)
    wakeup(widget)
end

return activelook
