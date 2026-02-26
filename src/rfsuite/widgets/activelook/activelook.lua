--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activelook = {}

local os_clock = os.clock
local floor = math.floor
local format = string.format
local concat = table.concat

local REDRAW_INTERVAL = 0.05
local OUTER_PADDING = 8
local ICON_SMALL = 28
local ICON_LARGE = 40
local ICON_GAP = 8
local LARGE_FONT = 3
local SMALL_FONT = 2
local PREFLIGHT_TOP_FONT = 3
local PREFLIGHT_BOTTOM_FONT = 1

local getSensorValue

local FONT_PX = {
    [1] = 24,
    [2] = 38,
    [3] = 64,
    [4] = 75,
    [5] = 82
}

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local DEFAULT_LAYOUT = {
    preflight = {"governor", "armed", "flightmode", "off"},
    inflight = {"current", "voltage", "fuel", "timer"},
    postflight = {"current", "voltage", "fuel", "timer"}
}

local DEFAULT_LAYOUT_CHOICE = {
    preflight = "two_top_one_bottom",
    inflight = "one_top_two_bottom",
    postflight = "two_top_two_bottom"
}

local LAYOUT_ACTIVE = {
    two_top_one_bottom = {true, true, true, false},
    two_top_two_bottom = {true, true, true, true},
    one_centered = {true, false, false, false},
    one_top_two_bottom = {true, false, true, true},
    stacked_three = {true, true, true, false}
}

local SENSOR_DEFS = {
    off = {
        label = "Off"
    },
    flightmode = {
        label = "Flight Mode",
        icon = {small = 4, large = 36}, -- cadence icon set
        value = function(_, mode)
            if mode == "inflight" then return "FLY" end
            if mode == "postflight" then return "POST" end
            return "PRE"
        end
    },
    timer = {
        label = "Timer",
        icon = {small = 8, large = 40}, -- chrono
        value = function(context)
            return context.lastFlightSecondsText or "00:00"
        end
    },
    governor = {
        label = "Governor",
        value = function()
            local raw = getSensorValue("governor")
            if raw ~= nil and type(raw) == "number" then raw = floor(raw) end
            return rfsuite.utils.getGovernorState(raw)
        end
    },
    armed = {
        label = "Armed",
        value = function()
            local session = rfsuite.session
            if session and session.isArmed ~= nil then
                if session.isArmed then return "@i18n(widgets.governor.ARMED):upper()@" end
                return "@i18n(widgets.governor.DISARMED):upper()@"
            end
            local flags = getSensorValue("armflags")
            if flags == 1 or flags == 3 then return "@i18n(widgets.governor.ARMED):upper()@" end
            if flags == 0 or flags == 2 then return "@i18n(widgets.governor.DISARMED):upper()@" end
            return "@i18n(widgets.governor.UNKNOWN):upper()@"
        end
    },
    fuel = {
        label = "Fuel",
        icon = {small = 1, large = 33}, -- battery-low
        value = function(_, _, _, getSensor)
            local fuel = getSensor("smartfuel")
            if fuel == nil then fuel = getSensor("fuel") end
            return fuel
        end,
        decimals = 0,
        suffix = "%"
    },
    current = {
        label = "Current",
        icon = {small = 19, large = 51}, -- power
        value = function(_, _, _, getSensor) return getSensor("current") end,
        decimals = 1,
        suffix = "A"
    },
    voltage = {
        label = "Voltage",
        icon = {small = 0, large = 32}, -- battery
        value = function(_, _, _, getSensor) return getSensor("voltage") end,
        decimals = 1,
        suffix = "V"
    },
    headspeed = {
        label = "Headspeed",
        icon = {small = 26, large = 58}, -- speed
        value = function(_, _, _, getSensor) return getSensor("rpm") end,
        decimals = 0,
        suffix = ""
    },
    temp_esc = {
        label = "ESC Temp",
        value = function(_, _, _, getSensor, getSensorUnit)
            return getSensorUnit("temp_esc")
        end,
        decimals = 0,
        useUnit = true
    },
    temp_mcu = {
        label = "MCU Temp",
        value = function(_, _, _, getSensor, getSensorUnit)
            return getSensorUnit("temp_mcu")
        end,
        decimals = 0,
        useUnit = true
    },
    link = {
        label = "Link",
        value = function(_, _, _, getSensor) return getSensor("link") end,
        decimals = 0,
        suffix = "dB"
    }
}

local function getMode()
    local mode = rfsuite.flightmode and rfsuite.flightmode.current
    if mode == "preflight" or mode == "inflight" or mode == "postflight" then
        return mode
    end
    return "preflight"
end

getSensorValue = function(name)
    local telemetry = rfsuite.tasks and rfsuite.tasks.telemetry
    local getter = telemetry and telemetry.getSensor
    if not getter then return nil end
    local value = getter(name)
    return value
end

local function getSensorValueWithUnit(name)
    local telemetry = rfsuite.tasks and rfsuite.tasks.telemetry
    local getter = telemetry and telemetry.getSensor
    if not getter then return nil end
    local value, _, minor = getter(name)
    return value, minor
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

local function estimateTextWidth(text, fontId)
    local px = FONT_PX[fontId] or 24
    local width = #tostring(text or "") * (px * 0.6)
    return width
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
    context.lastFlightSecondsText = formatDuration(context.lastFlightSeconds)
end

local function loadLayoutForState(stateKey)
    local prefs = rfsuite.preferences and rfsuite.preferences.activelook or {}
    local defaults = DEFAULT_LAYOUT[stateKey] or DEFAULT_LAYOUT.preflight
    local layout = {}
    local prefix = stateKey .. "_"
    for i = 1, 4 do
        local key = prefix .. i
        local value = prefs[key]
        if value == nil or value == "" then
            local legacy = prefs["prepost_" .. i]
            value = legacy or defaults[i]
        end
        layout[i] = value
    end
    return layout
end

local function loadLayoutChoice(stateKey)
    local prefs = rfsuite.preferences and rfsuite.preferences.activelook or {}
    local key = "layout_" .. stateKey
    local choice = prefs[key] or DEFAULT_LAYOUT_CHOICE[stateKey] or "two_top_two_bottom"
    if not LAYOUT_ACTIVE[choice] then
        choice = DEFAULT_LAYOUT_CHOICE[stateKey] or "two_top_two_bottom"
    end
    return choice
end

local function layoutKey(layout)
    return concat(layout, "|")
end

local function buildLayout(context)
    local w, h = glasses.getWindowSize()
    local padding = OUTER_PADDING
    local areaW = w - (padding * 2)
    local areaH = h - (padding * 2)
    local scale = (areaH > 0) and (areaH / 256) or 1
    local y1 = floor(8 * scale)
    local y2 = floor(88 * scale)
    local y3 = floor(186 * scale)
    local midX = floor(areaW * 0.5) + floor(6 * scale)
    local gap = math.max(4, floor(ICON_GAP * scale))
    local largeOffset = floor(8 * scale)
    local smallOffset = floor(6 * scale)

    local prefs = rfsuite.preferences and rfsuite.preferences.activelook or {}
    local offsetX = clamp(tonumber(prefs.offset_x) or 0, -20, 20)
    local offsetY = clamp(tonumber(prefs.offset_y) or 0, -20, 20)

    context.offsetX = offsetX
    context.offsetY = offsetY

    context.layout = glasses.createLayout({
        x = math.floor(padding + 0.5),
        y = math.floor(padding + 0.5),
        w = areaW,
        h = areaH,
        text = {x = 0, y = 0, font = 1},
        border = false
    })

    local topRowY = y1 + offsetY
    local midRowY = y2 + offsetY
    local bottomRowY = y3 + offsetY
    local boxW = floor((areaW - gap) * 0.5)
    local rightX = offsetX + boxW + gap
    local centerX = offsetX + floor((areaW - boxW) * 0.5)
    local preflightTopOffset = largeOffset + floor(6 * scale)
    local preflightBottomOffset = floor(2 * scale)

    context.layoutMetrics = {
        areaW = areaW,
        offsetX = offsetX,
        offsetY = offsetY,
        topRowY = topRowY,
        midRowY = midRowY,
        bottomRowY = bottomRowY,
        boxW = boxW,
        rightX = rightX,
        centerX = centerX,
        gap = gap,
        largeOffset = largeOffset,
        smallOffset = smallOffset,
        preflightTopOffset = preflightTopOffset,
        preflightBottomOffset = preflightBottomOffset
    }

    context.iconGap = gap
end

local function needsRedraw(context, modeKey, values, icons, configKeyValue)
    if modeKey ~= context.lastMode then return true end
    if configKeyValue ~= context.lastConfigKey then return true end
    for i = 1, #values do
        if values[i] ~= context.lastValues[i] then return true end
        if icons[i] ~= context.lastIcons[i] then return true end
    end
    return false
end

local function render(context, values, icons, modeKey, configKeyValue, slots)
    local commands = {}
    local slotList = slots or context.slotLayout or {}
    local function toInt(value)
        if type(value) ~= "number" then return 0 end
        if value >= 0 then return math.floor(value + 0.5) end
        return math.ceil(value - 0.5)
    end

    for i = 1, #values do
        local slot = slotList[i]
        if slot and slot.enabled ~= false then
            local iconId = icons[i]
            local text = values[i] or "-"
            local textX = slot.x
            local iconX = slot.x
            local iconSize = (slot.size == "large") and ICON_LARGE or ICON_SMALL
            if slot.align == "center" and slot.width then
                local estimate = estimateTextWidth(text, slot.font)
                local contentWidth = estimate
                if iconId then
                    contentWidth = iconSize + (context.iconGap or ICON_GAP) + estimate
                end
                local startX = slot.x + math.max(0, (slot.width - contentWidth) * 0.5)
                iconX = startX
                textX = iconId and (startX + iconSize + (context.iconGap or ICON_GAP)) or startX
            elseif iconId then
                textX = slot.x + iconSize + (context.iconGap or ICON_GAP)
            end
            if iconId then
                commands[#commands + 1] = {bitmap = {id = iconId, x = toInt(iconX), y = toInt(slot.y)}}
            end
            commands[#commands + 1] = {
                text = {
                    text = text,
                    x = toInt(textX),
                    y = toInt(slot.y + (slot.textYOffset or 0)),
                    font = slot.font
                }
            }
        end
    end

    context.layout:clearAndDisplayExtended({
        x = 0,
        y = 0,
        text = "",
        commands = commands
    })

    context.lastMode = modeKey
    context.lastConfigKey = configKeyValue
    for i = 1, #values do
        context.lastValues[i] = values[i]
        context.lastIcons[i] = icons[i]
    end
end

local function buildValues(context, mode, now, layout)
    updateStats(context, mode, now)
    local values, icons = {}, {}
    for i = 1, 4 do
        local sensorKey = layout[i] or "off"
        local def = SENSOR_DEFS[sensorKey] or SENSOR_DEFS.off
        local value
        local unit
        if def.value then
            value, unit = def.value(context, mode, now, function(name)
                return toNumber(getSensorValue(name))
            end, function(name)
                local v, u = getSensorValueWithUnit(name)
                return toNumber(v), u
            end)
        end
        if value == nil then
            value = "-"
        elseif def.decimals ~= nil then
            local suffix = def.suffix
            if def.useUnit and unit and unit ~= "" then suffix = unit end
            value = formatNumber(value, def.decimals, suffix)
        else
            value = tostring(value)
        end
        values[i] = value
        icons[i] = nil
    end
    return values, icons
end

local function computeSlots(context, modeKey, layoutChoice)
    local metrics = context.layoutMetrics or {}
    local slots = {}
    local active = LAYOUT_ACTIVE[layoutChoice] or LAYOUT_ACTIVE.two_top_two_bottom
    local areaW = metrics.areaW or 0
    local boxW = metrics.boxW or 0
    local leftX = metrics.offsetX or 0
    local rightX = metrics.rightX or 0
    local centerX = metrics.centerX or 0
    local topY = metrics.topRowY or 0
    local midY = metrics.midRowY or 0
    local bottomY = metrics.bottomRowY or 0
    local largeOffset = metrics.largeOffset or 0
    local smallOffset = metrics.smallOffset or 0
    local preTopOffset = metrics.preflightTopOffset or largeOffset
    local preBottomOffset = metrics.preflightBottomOffset or smallOffset
    local isPreflight = modeKey == "preflight"

    local function addSlot(idx, enabled, x, y, size, font, textYOffset, width, align)
        slots[idx] = {
            enabled = enabled,
            x = x,
            y = y,
            size = size,
            font = font,
            textYOffset = textYOffset,
            width = width,
            align = align
        }
    end

    if layoutChoice == "two_top_one_bottom" then
        addSlot(1, active[1], leftX, topY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, boxW, isPreflight and "center" or nil)
        addSlot(2, active[2], rightX, topY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, boxW, isPreflight and "center" or nil)
        addSlot(3, active[3], centerX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, "center")
        addSlot(4, active[4], rightX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, isPreflight and "center" or nil)
    elseif layoutChoice == "stacked_three" then
        addSlot(1, active[1], leftX, topY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, areaW, "center")
        addSlot(2, active[2], leftX, midY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, areaW, "center")
        addSlot(3, active[3], leftX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, areaW, "center")
        addSlot(4, active[4], rightX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, isPreflight and "center" or nil)
    elseif layoutChoice == "one_centered" then
        addSlot(1, active[1], leftX, midY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, areaW, "center")
        addSlot(2, active[2], rightX, midY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, boxW, isPreflight and "center" or nil)
        addSlot(3, active[3], leftX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, isPreflight and "center" or nil)
        addSlot(4, active[4], rightX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, isPreflight and "center" or nil)
    elseif layoutChoice == "one_top_two_bottom" then
        addSlot(1, active[1], leftX, topY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, areaW, "center")
        addSlot(2, active[2], rightX, topY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, boxW, isPreflight and "center" or nil)
        addSlot(3, active[3], leftX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, isPreflight and "center" or nil)
        addSlot(4, active[4], rightX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, isPreflight and "center" or nil)
    else
        addSlot(1, active[1], leftX, topY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, boxW, isPreflight and "center" or nil)
        addSlot(2, active[2], rightX, topY, "large", isPreflight and PREFLIGHT_TOP_FONT or LARGE_FONT, isPreflight and preTopOffset or largeOffset, boxW, isPreflight and "center" or nil)
        addSlot(3, active[3], leftX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, isPreflight and "center" or nil)
        addSlot(4, active[4], rightX, bottomY, "small", isPreflight and PREFLIGHT_BOTTOM_FONT or SMALL_FONT, isPreflight and preBottomOffset or smallOffset, boxW, isPreflight and "center" or nil)
    end

    return slots
end

local function create()
    return {
        layout = nil,
        lastDraw = 0,
        lastMode = nil,
        lastConfigKey = nil,
        lastValues = {},
        lastIcons = {},
        inflight = false,
        inflightStart = nil,
        lastFlightSeconds = 0,
        lastFlightSecondsText = "00:00"
    }
end

local function wakeup(context)
    if rfsuite.session and rfsuite.session.activelookReset then
        rfsuite.session.activelookReset = false
        context.layout = nil
        context.lastMode = nil
        context.lastConfigKey = nil
        context.lastValues = {}
        context.lastIcons = {}
    end

    local prefs = rfsuite.preferences and rfsuite.preferences.activelook or {}
    local offsetX = clamp(tonumber(prefs.offset_x) or 0, -20, 20)
    local offsetY = clamp(tonumber(prefs.offset_y) or 0, -20, 20)
    if context.offsetX ~= offsetX or context.offsetY ~= offsetY then
        context.layout = nil
        context.lastMode = nil
        context.lastConfigKey = nil
    end

    if not context.layout then buildLayout(context) end
    local now = os_clock()
    if (now - (context.lastDraw or 0)) < REDRAW_INTERVAL then return end
    context.lastDraw = now

    local mode = getMode()
    local stateKey = mode
    local layout = loadLayoutForState(stateKey)
    local layoutChoice = loadLayoutChoice(stateKey)
    local configKeyValue = layoutChoice .. "|" .. layoutKey(layout)
    local slots = computeSlots(context, stateKey, layoutChoice)

    local values, icons = buildValues(context, mode, now, layout)
    if needsRedraw(context, stateKey, values, icons, configKeyValue) then
        render(context, values, icons, stateKey, configKeyValue, slots)
    end
end

function activelook.create()
    return create()
end

function activelook.build(widget)
    buildLayout(widget)
end

function activelook.wakeup(widget)
    wakeup(widget)
end

return activelook
