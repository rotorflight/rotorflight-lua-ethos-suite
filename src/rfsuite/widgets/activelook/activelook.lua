--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local activelook = {}

local os_clock = os.clock
local floor = math.floor
local format = string.format

local FALLBACK_WIDTH = 100
local FALLBACK_HEIGHT = 100
local REDRAW_INTERVAL = 0.5
local LEFT_MARGIN = 2
local TOP_MARGIN = 4
local MAX_LAYOUT_LINES = 3

local SLOT_TITLES = {
    line1 = "CURRENT:",
    line2 = "VOLTAGE:",
    line3 = "FUEL:",
    line4 = "TIMER:"
}

local VALID_MODES = {preflight = true, inflight = true, postflight = true}
local MODES = {"preflight", "inflight", "postflight"}

local MODE_ROWS = {
    preflight = {"line1", "line2", "line3", "line4"},
    inflight = {"line1", "line2", "line3", "line4"},
    postflight = {"line1", "line2", "line3", "line4"}
}

local defaultContext = nil

local function logInfo(message)
    if rfsuite and rfsuite.utils and rfsuite.utils.log then
        rfsuite.utils.log(message, "info")
    end
end

local function hasGlassesApi()
    if type(glasses) ~= "table" then return false end
    return type(glasses.createLayout) == "function"
        and type(glasses.layoutClearAndDisplay) == "function"
        and type(glasses.getWindowSize) == "function"
end

local function getWindowSize()
    if type(glasses) == "table" and type(glasses.getWindowSize) == "function" then
        local w, h = glasses.getWindowSize()
        if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
            return w, h
        end
    end
    return FALLBACK_WIDTH, FALLBACK_HEIGHT
end

local function layoutSet(layout, text)
    if not layout then return false, "layout=nil" end
    local ok, err = pcall(glasses.layoutClearAndDisplay, layout, text or "")
    if not ok then return false, tostring(err) end
    return true
end

local function clearModeLayouts(layouts)
    for _, entry in ipairs(layouts or {}) do
        if entry then
            if entry.layout then layoutSet(entry.layout, "") end
            if entry.titleLayout then layoutSet(entry.titleLayout, "") end
            if entry.valueLayout then layoutSet(entry.valueLayout, "") end
        end
    end
end

local function resetModeCache(context, mode)
    if context and context.lastRendered then
        context.lastRendered[mode] = {}
    end
end

local function getSensor(name)
    local telemetry = rfsuite.tasks and rfsuite.tasks.telemetry
    local getter = telemetry and telemetry.getSensor
    if not getter then return nil end
    return getter(name)
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
    if type(seconds) ~= "number" or seconds < 0 then return "--:--" end
    local total = floor(seconds + 0.5)
    local mins = floor(total / 60)
    local secs = total % 60
    return format("%02d:%02d", mins, secs)
end

local function modeFromSession()
    local mode = rfsuite.flightmode and rfsuite.flightmode.current
    if VALID_MODES[mode] then return mode end
    return "preflight"
end

local function readGovernorText(raw)
    local utils = rfsuite and rfsuite.utils
    if utils and type(utils.getGovernorState) == "function" then
        return tostring(utils.getGovernorState(raw) or "-")
    end
    return tostring(raw or "-")
end

local function readFlightSeconds(context, mode, now)
    local timer = rfsuite.session and rfsuite.session.timer

    if mode == "inflight" then
        if timer and type(timer.live) == "number" then return timer.live end
        if context.stats.inflightStart then return now - context.stats.inflightStart end
    end

    if mode == "postflight" then
        if timer and type(timer.session) == "number" and timer.session > 0 then return timer.session end
    end

    return context.stats.lastFlightSeconds or 0
end

local function updateStats(context, mode, snapshot, now)
    if mode == "inflight" then
        if not context.stats.inflight then
            context.stats.inflight = true
            context.stats.inflightStart = now
            context.stats.minVoltage = nil
        end

        if type(snapshot.voltage) == "number" then
            if type(context.stats.minVoltage) ~= "number" or snapshot.voltage < context.stats.minVoltage then
                context.stats.minVoltage = snapshot.voltage
            end
        end

        context.stats.lastFlightSeconds = readFlightSeconds(context, "inflight", now)
        return
    end

    if context.stats.inflight then
        context.stats.lastFlightSeconds = readFlightSeconds(context, "postflight", now)
    end

    context.stats.inflight = false
    context.stats.inflightStart = nil
end

local function composeLines(context, mode, snapshot, now)
    local fuel = snapshot.smartfuel
    if type(fuel) ~= "number" then fuel = snapshot.fuel end
    local secs = readFlightSeconds(context, mode, now)
    return {
        line1 = formatNumber(snapshot.current, 1, "A"),
        line2 = formatNumber(snapshot.voltage, 1, "V"),
        line3 = formatNumber(fuel, 0, "%"),
        line4 = formatDuration(secs)
    }
end

local function buildModeLayouts(context, mode)
    local modeSlots = MODE_ROWS[mode] or {}
    local slots = {}
    for i = 1, #modeSlots do
        if i > MAX_LAYOUT_LINES then break end
        slots[#slots + 1] = modeSlots[i]
    end

    local layouts = {}
    local count = #slots
    if count == 0 then return layouts end

    local offsetX = context.offsetX or 0
    local offsetY = context.offsetY or 0
    local rowX = offsetX
    local rowW = context.w - rowX
    if rowW < 40 then rowW = context.w end

    local freeH = context.h - (TOP_MARGIN * 2)
    local rowH = floor(freeH / count)
    if rowH < 10 then rowH = 10 end

    local titleW = floor(rowW * 0.56)
    if titleW < 44 then titleW = 44 end
    if titleW > rowW - 24 then titleW = rowW - 24 end
    local valueW = rowW - titleW
    if valueW < 20 then
        valueW = 20
        titleW = rowW - valueW
    end

    for i, slot in ipairs(slots) do
        local y = TOP_MARGIN + ((i - 1) * rowH) + offsetY
        local titleSpec = {
            x = rowX,
            y = y,
            width = titleW,
            height = rowH,
            text = {x = LEFT_MARGIN, y = 0},
            border = false
        }
        local valueSpec = {
            x = rowX + titleW,
            y = y,
            width = valueW,
            height = rowH,
            text = {x = 0, y = 0},
            border = false
        }

        local titleLayout = glasses.createLayout(titleSpec)
        local valueLayout = glasses.createLayout(valueSpec)

        logInfo(
            "ActiveLook build mode=" .. tostring(mode)
                .. " slot=" .. tostring(slot)
                .. " x=" .. tostring(rowX) .. " y=" .. tostring(y)
                .. " tw=" .. tostring(titleW)
                .. " vw=" .. tostring(valueW)
                .. " h=" .. tostring(rowH)
                .. " titleLayout=" .. tostring(titleLayout)
                .. " valueLayout=" .. tostring(valueLayout)
        )

        layouts[#layouts + 1] = {
            slot = slot,
            title = SLOT_TITLES[slot] or (tostring(slot) .. ":"),
            titleLayout = titleLayout,
            valueLayout = valueLayout
        }
    end

    return layouts
end

local function buildAllLayouts(context)
    clearModeLayouts(context.layouts.preflight)
    clearModeLayouts(context.layouts.inflight)
    clearModeLayouts(context.layouts.postflight)
    if context.fullLayout then layoutSet(context.fullLayout, "") end

    context.layouts.preflight = {}
    context.layouts.inflight = {}
    context.layouts.postflight = {}
    context.fullLayout = glasses.createLayout({
        x = 0,
        y = 0,
        width = context.w,
        height = context.h,
        text = {x = 0, y = 0},
        border = false
    })

    context.lastMode = nil
end

local function ensureModeLayouts(context, mode)
    local layouts = context.layouts[mode]
    if type(layouts) == "table" and #layouts > 0 then return end
    context.layouts[mode] = buildModeLayouts(context, mode)
end

local function renderMode(context, mode, values, force)
    local layouts = context.layouts[mode] or {}
    local cache = context.lastRendered and context.lastRendered[mode] or nil

    for _, entry in ipairs(layouts) do
        if force and entry.titleLayout then
            local ok, err = layoutSet(entry.titleLayout, tostring(entry.title or ""))
            if not ok then
                logInfo("ActiveLook title render failed mode=" .. tostring(mode) .. " slot=" .. tostring(entry.slot) .. " err=" .. tostring(err))
            end
        end

        local valueText = tostring(values[entry.slot] or "-")
        if force or not cache or cache[entry.slot] ~= valueText then
            local ok, err = layoutSet(entry.valueLayout, valueText)
            if not ok then
                logInfo("ActiveLook value render failed mode=" .. tostring(mode) .. " slot=" .. tostring(entry.slot) .. " err=" .. tostring(err))
            elseif cache then
                cache[entry.slot] = valueText
            end
        end
    end
end

local function fullRefresh(context)
    if context and context.fullLayout then
        layoutSet(context.fullLayout, "")
    end
end

local function maybeRequestNextWakeup()
    if type(lcd) == "table" and type(lcd.invalidate) == "function" then
        lcd.invalidate()
    end
end

local function resetState(context)
    context.built = false
    context.layouts = {preflight = {}, inflight = {}, postflight = {}}
    context.lastRendered = {preflight = {}, inflight = {}, postflight = {}}
    context.lastMode = nil
    context.lastWakeup = 0
    context.fullLayout = nil
    context.stats = {
        inflight = false,
        inflightStart = nil,
        lastFlightSeconds = 0,
        minVoltage = nil
    }
end

local function newContext()
    return {
        built = false,
        w = FALLBACK_WIDTH,
        h = FALLBACK_HEIGHT,
        layouts = {preflight = {}, inflight = {}, postflight = {}},
        lastRendered = {preflight = {}, inflight = {}, postflight = {}},
        lastMode = nil,
        lastWakeup = 0,
        fullLayout = nil,
        offsetX = 0,
        offsetY = 0,
        stats = {
            inflight = false,
            inflightStart = nil,
            lastFlightSeconds = 0,
            minVoltage = nil
        }
    }
end

local function getContext(widget)
    if type(widget) == "table" then return widget end
    if not defaultContext then defaultContext = newContext() end
    return defaultContext
end

function activelook.create()
    local context = newContext()
    defaultContext = context
    return context
end

function activelook.reset(widget)
    local context = getContext(widget)
    if hasGlassesApi() then
        clearModeLayouts(context.layouts.preflight)
        clearModeLayouts(context.layouts.inflight)
        clearModeLayouts(context.layouts.postflight)
        fullRefresh(context)
    end
    resetState(context)
    logInfo("ActiveLook reset")
end

function activelook.build(widget)
    local context = getContext(widget)
    if not hasGlassesApi() then return end

    local prefs = rfsuite.preferences and rfsuite.preferences.activelook or {}
    context.offsetX = tonumber(prefs and prefs.offset_x) or 0
    context.offsetY = tonumber(prefs and prefs.offset_y) or 0

    local w, h = getWindowSize()
    context.w = w
    context.h = h
    buildAllLayouts(context)
    context.lastRendered = {preflight = {}, inflight = {}, postflight = {}}
    context.lastWakeup = 0
    context.built = true

    logInfo("ActiveLook window w=" .. tostring(w) .. " h=" .. tostring(h))
end

function activelook.wakeup(widget)
    local context = getContext(widget)
    if not hasGlassesApi() then return end

    if rfsuite.session and rfsuite.session.activelookReset then
        rfsuite.session.activelookReset = false
        activelook.reset(context)
    end

    local prefs = rfsuite.preferences and rfsuite.preferences.activelook or {}
    local offsetX = tonumber(prefs and prefs.offset_x) or 0
    local offsetY = tonumber(prefs and prefs.offset_y) or 0

    local w, h = getWindowSize()
    if not context.built or context.w ~= w or context.h ~= h or context.offsetX ~= offsetX or context.offsetY ~= offsetY then
        activelook.build(context)
    end

    local now = os_clock()
    if (now - (context.lastWakeup or 0)) < REDRAW_INTERVAL then
        maybeRequestNextWakeup()
        return
    end
    context.lastWakeup = now

    local mode = modeFromSession()
    local modeChanged = (mode ~= context.lastMode)
    if modeChanged then
        if context.lastMode then
            clearModeLayouts(context.layouts[context.lastMode])
            context.layouts[context.lastMode] = {}
            resetModeCache(context, context.lastMode)
        end
        resetModeCache(context, mode)
        context.lastMode = mode
    end

    ensureModeLayouts(context, mode)
    if modeChanged then fullRefresh(context) end

    local snapshot = {
        voltage = getSensor("voltage"),
        current = getSensor("current"),
        fuel = getSensor("fuel"),
        smartfuel = getSensor("smartfuel")
    }

    updateStats(context, mode, snapshot, now)

    local lines = composeLines(context, mode, snapshot, now)
    renderMode(context, mode, lines, modeChanged)

    maybeRequestNextWakeup()
end

return activelook
