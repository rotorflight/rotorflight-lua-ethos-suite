--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local model = model
local system = system

local floor = math.floor
local ceil = math.ceil
local format = string.format
local max = math.max
local pairs = pairs
local tostring = tostring
local type = type
local insert = table.insert

local utils = rfsuite.widgets.dashboard.utils
local maxVoltageToCellVoltage = utils.maxVoltageToCellVoltage

local common = {}

local function rgb(r, g, b)
    return lcd.RGB(r, g, b)
end

common.layout = {cols = 1, rows = 1, padding = 0, showstats = false}

common.basePalette = {
    -- HeliHUD fixed colors: midnight black, metallic blue, pearl white, status green, and blue-primary instruments.
    bg = rgb(1, 4, 8),
    bgalt = rgb(6, 14, 24),
    line = rgb(0, 132, 255),
    blue = rgb(0, 185, 255),
    green = rgb(70, 255, 55),
    white = rgb(245, 248, 255),
    yellow = rgb(255, 196, 34),
    orange = rgb(255, 145, 20),
    red = rgb(255, 54, 54),
    dim = rgb(28, 42, 55)
}

common.palette = common.basePalette

local paletteCache = {
    signature = nil,
    palette = nil,
    headerColorMode = nil
}

common.headerLayout = utils.standardHeaderLayout(utils.getHeaderOptions())

function common.getThemeSignature()
    return utils.getThemeSignature()
end

function common.getPalette()
    -- V5 final polish pass:
    -- Use a fixed HeliHUD palette instead of resolving the full EthOS theme colors every rebuild.
    -- This keeps the look consistent and removes unnecessary theme-color work from this theme.
    if paletteCache.palette then return paletteCache.palette end

    local base = common.basePalette
    local palette = {
        bg = base.bg,
        bgalt = base.bgalt,
        line = base.line,
        blue = base.blue,
        green = base.green,
        power = base.blue,
        white = base.white,
        yellow = base.yellow,
        orange = base.orange,
        red = base.red,
        dim = base.dim
    }

    paletteCache.signature = "helihud_fixed_v5"
    paletteCache.palette = palette
    paletteCache.headerColorMode = {
        fillwarncolor = palette.yellow,
        fillcolor = palette.power,
        fillcritcolor = palette.red,
        tbbgcolor = palette.bg,
        tbtextcolor = palette.white,
        titlecolor = palette.line,
        txbgfillcolor = palette.bgalt,
        txaccentcolor = palette.line,
        txfillcolor = palette.power,
        cntextcolor = palette.white,
        rssitextcolor = palette.white,
        rssifillcolor = palette.power,
        rssifillbgcolor = palette.bgalt
    }
    common.palette = palette
    common.headerColorMode = paletteCache.headerColorMode

    return palette
end
function common.getHeaderColorMode()
    local signature = utils.getThemeSignature()
    if paletteCache.headerColorMode == nil or paletteCache.signature ~= signature then
        common.getPalette()
    end
    return paletteCache.headerColorMode
end

local themeOptions = {
    ls_full = {
        bannerfont = "FONT_XXL",
        craftnamefont = "FONT_XL",
        headingfont = "FONT_L",
        leftlabelfont = "FONT_STD",
        leftvaluefont = "FONT_L",
        profilefont = "FONT_L",
        bigfont = "FONT_XXL",
        biglabelfont = "FONT_L",
        framefont = "FONT_STD",
        rightvaluefont = "FONT_XL",
        statusfont = "FONT_L",
        bottomtitlefont = "FONT_S",
        bottomvaluefont = "FONT_L"
    },
    ls_std = {
        bannerfont = "FONT_XXL",
        craftnamefont = "FONT_XL",
        headingfont = "FONT_L",
        leftlabelfont = "FONT_STD",
        leftvaluefont = "FONT_L",
        profilefont = "FONT_L",
        bigfont = "FONT_XXL",
        biglabelfont = "FONT_L",
        framefont = "FONT_STD",
        rightvaluefont = "FONT_XL",
        statusfont = "FONT_L",
        bottomtitlefont = "FONT_S",
        bottomvaluefont = "FONT_L"
    },
    ms_full = {
        bannerfont = "FONT_XL",
        craftnamefont = "FONT_XL",
        headingfont = "FONT_L",
        leftlabelfont = "FONT_STD",
        leftvaluefont = "FONT_L",
        profilefont = "FONT_STD",
        bigfont = "FONT_XXL",
        biglabelfont = "FONT_L",
        framefont = "FONT_STD",
        rightvaluefont = "FONT_XL",
        statusfont = "FONT_STD",
        bottomtitlefont = "FONT_XS",
        bottomvaluefont = "FONT_STD"
    },
    ms_std = {
        bannerfont = "FONT_XL",
        craftnamefont = "FONT_XL",
        headingfont = "FONT_L",
        leftlabelfont = "FONT_STD",
        leftvaluefont = "FONT_L",
        profilefont = "FONT_STD",
        bigfont = "FONT_XXL",
        biglabelfont = "FONT_L",
        framefont = "FONT_STD",
        rightvaluefont = "FONT_XL",
        statusfont = "FONT_STD",
        bottomtitlefont = "FONT_XS",
        bottomvaluefont = "FONT_STD"
    },
    ss_full = {
        bannerfont = "FONT_XL",
        craftnamefont = "FONT_XL",
        headingfont = "FONT_L",
        leftlabelfont = "FONT_STD",
        leftvaluefont = "FONT_L",
        profilefont = "FONT_STD",
        bigfont = "FONT_XXL",
        biglabelfont = "FONT_L",
        framefont = "FONT_STD",
        rightvaluefont = "FONT_XL",
        statusfont = "FONT_STD",
        bottomtitlefont = "FONT_XS",
        bottomvaluefont = "FONT_STD"
    },
    ss_std = {
        bannerfont = "FONT_L",
        craftnamefont = "FONT_L",
        headingfont = "FONT_STD",
        leftlabelfont = "FONT_S",
        leftvaluefont = "FONT_STD",
        profilefont = "FONT_S",
        bigfont = "FONT_XL",
        biglabelfont = "FONT_STD",
        framefont = "FONT_S",
        rightvaluefont = "FONT_L",
        statusfont = "FONT_S",
        bottomtitlefont = "FONT_XXS",
        bottomvaluefont = "FONT_S"
    }
}

local function round(v)
    return floor(v + 0.5)
end

local FONT_ORDER = {}
local FONT_RANK = {}

do
    local fontNames = {"FONT_XXXXL", "FONT_XXL", "FONT_XL", "FONT_L", "FONT_STD", "FONT_S", "FONT_XS", "FONT_XXS"}
    for i = 1, #fontNames do
        local font = utils.resolveFont(fontNames[i], nil)
        if type(font) == "number" then
            insert(FONT_ORDER, font)
            FONT_RANK[font] = #FONT_ORDER
        end
    end
end

local function trim(str)
    if type(str) ~= "string" then return str end
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end

local function compileTransform(t, decimals)
    local pow = decimals and (10 ^ decimals) or nil
    local function applyRound(v)
        return pow and (floor(v * pow + 0.5) / pow) or v
    end

    if type(t) == "number" then
        local mul = t
        return function(v) return applyRound(v * mul) end
    elseif t == "floor" then
        return function(v) return floor(v) end
    elseif t == "ceil" then
        return function(v) return ceil(v) end
    elseif t == "round" or t == nil then
        return function(v) return applyRound(v) end
    elseif type(t) == "function" then
        return t
    end

    return function(v) return v end
end

local function resolveThresholdColor(value, defaultColor, thresholds, colorKey)
    local resolvedKey = colorKey or "textcolor"
    local color = utils.resolveThemeColor(resolvedKey, defaultColor)
    if not thresholds or value == nil then return color end

    for i = 1, #thresholds do
        local threshold = thresholds[i]
        local thresholdValue = threshold.value
        if type(thresholdValue) == "function" then thresholdValue = thresholdValue(value) end

        if type(value) == "string" and thresholdValue == value and threshold[resolvedKey] then
            color = utils.resolveThemeColor(resolvedKey, threshold[resolvedKey])
            break
        elseif type(value) == "number" and type(thresholdValue) == "number" and value <= thresholdValue and threshold[resolvedKey] then
            color = utils.resolveThemeColor(resolvedKey, threshold[resolvedKey])
            break
        end
    end

    return color
end

local function pickFont(preferred, text, maxW, maxH)
    local fallback = utils.resolveFont("FONT_STD", utils.resolveFont("FONT_S", preferred))
    local best = preferred or FONT_ORDER[#FONT_ORDER] or fallback
    local start = FONT_RANK[preferred] or 1

    for i = start, #FONT_ORDER do
        local font = FONT_ORDER[i]
        lcd.font(font)
        local tw, th = lcd.getTextSize(text)
        best = font
        if tw <= maxW and th <= maxH then return font, tw, th end
    end

    lcd.font(best)
    local tw, th = lcd.getTextSize(text)
    return best, tw, th
end

local function currentWatts(telemetry)
    local voltage = telemetry and telemetry.getSensor and telemetry.getSensor("voltage")
    local current = telemetry and telemetry.getSensor and telemetry.getSensor("current")
    if voltage and current then return voltage * current end
    return nil
end

local function statsWatts(telemetry, stattype)
    local vStats = telemetry and telemetry.sensorStats and telemetry.sensorStats.voltage
    local iStats = telemetry and telemetry.sensorStats and telemetry.sensorStats.current
    if not (vStats and iStats) then return nil end

    local sv = vStats[stattype]
    local si = iStats[stattype]
    if sv and si then return sv * si end
    return nil
end

local function resolveTelemetryUnit(spec, dynamicUnit, telemetry)
    if spec.unit ~= nil then return spec.unit end
    if dynamicUnit ~= nil then return dynamicUnit end
    if spec.source and telemetry and telemetry.sensorTable and telemetry.sensorTable[spec.source] then
        return telemetry.sensorTable[spec.source].unit_string or ""
    end
    return ""
end

local function readTelemetry(spec, telemetry)
    if not (telemetry and spec.source) then return nil, nil, nil end
    return telemetry.getSensor(spec.source, nil, nil, spec.thresholds)
end

local function readStats(spec, telemetry)
    if not (telemetry and spec.source and telemetry.getSensorStats) then return nil, nil, nil end

    local stats = telemetry.getSensorStats(spec.source)
    if not stats then return nil, nil, nil end

    local value = stats[spec.stattype or "max"]
    local unit
    local localizedThresholds = spec.thresholds
    local sensorDef = telemetry.sensorTable and telemetry.sensorTable[spec.source]

    if sensorDef then
        unit = sensorDef.unit_string
        if type(sensorDef.localizations) == "function" and value ~= nil then
            local localizedValue, _, localizedUnit, _, _, thresholds = sensorDef.localizations(value, nil, nil, spec.thresholds)
            if localizedValue ~= nil then value = localizedValue end
            if localizedUnit ~= nil then unit = localizedUnit end
            if thresholds ~= nil then localizedThresholds = thresholds end
        end
    end

    return value, unit, localizedThresholds
end

local function readGovernor(telemetry)
    local raw = telemetry and telemetry.getSensor and telemetry.getSensor("governor")
    if raw == nil then return nil end

    local display = rfsuite.utils.getGovernorState(raw)
    if type(display) == "string" and display:find(",", 1, true) then
        display = trim(display:match("([^,]+)")) or display
    end
    return display
end

local function readArmflags(telemetry, showReason)
    local value = telemetry and telemetry.getSensor and telemetry.getSensor("armflags")
    local disableflags = telemetry and telemetry.getSensor and telemetry.getSensor("armdisableflags")

    if showReason and disableflags ~= nil and rfsuite.utils.armingDisableFlagsToString then
        local reason = rfsuite.utils.armingDisableFlagsToString(floor(disableflags))
        if reason and reason ~= "OK" then return reason end
    end

    if value == nil then return nil end
    if value == 1 or value == 3 then return "ARMED" end
    return "DISARMED"
end


local function updateEscTempTracker(telemetry, tempValue)
    -- HeliHUD V8: track MAX ESC TEMP ourselves from the same live value
    -- used on the in-flight page. RotorFlight stats for temp_esc can report
    -- impossible spikes on some setups, so the flight report does not trust it.
    local session = rfsuite.session or {}
    rfsuite.session = session

    local armState = readArmflags(telemetry, false)
    local armed = armState == "ARMED"

    if armed and not session.helihudWasArmed then
        session.helihudEscTempMax = nil
    end
    session.helihudWasArmed = armed

    if armed and type(tempValue) == "number" then
        if session.helihudEscTempMax == nil or tempValue > session.helihudEscTempMax then
            session.helihudEscTempMax = tempValue
        end
    end

    return session.helihudEscTempMax
end

local function readTrackedEscTempMax(spec, telemetry)
    -- Give the tracker a chance to update if the report page is viewed while armed,
    -- but normally this returns the value captured during the in-flight page.
    local liveValue, _, dynamicUnit, _, _, thresholds = readTelemetry({source = "temp_esc", thresholds = spec.thresholds}, telemetry)
    updateEscTempTracker(telemetry, liveValue)

    local session = rfsuite.session or {}
    return session.helihudEscTempMax, dynamicUnit, thresholds
end


local function readCurrentAlias(telemetry)
    -- Final-pass current resolver. First use RotorFlight's official key.
    -- If that source is not found on this radio, fall back to common EthOS
    -- sensor names/appIds used by S.Port/CRSF/MSP current telemetry.
    if telemetry and telemetry.getSensor then
        local keys = {"current", "esc_current", "current_meter", "curr", "esc1_current", "amperage", "amps"}
        for i = 1, #keys do
            local v = telemetry.getSensor(keys[i])
            if type(v) == "number" then return v end
        end
    end

    if system and system.getSource then
        local candidates = {
            "Current", "Curr", "CURRENT", "ESC Current", "ESC1 Current", "Rx Curr",
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1012},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x1042},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x104A},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0200},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0208},
            {category = CATEGORY_TELEMETRY_SENSOR, appId = 0x0201}
        }
        for i = 1, #candidates do
            local ok, src = pcall(system.getSource, candidates[i])
            if ok and src and type(src.value) == "function" then
                local v = src:value()
                if type(v) == "number" then return v end
            end
        end
    end

    return nil
end

local function formatTimeSeconds(seconds, withHours)
    if type(seconds) ~= "number" then return nil end
    if withHours then
        local hours = floor(seconds / 3600)
        local minutes = floor((seconds % 3600) / 60)
        local secs = floor(seconds % 60)
        return format("%02d:%02d:%02d", hours, minutes, secs)
    end

    local minutes = floor(seconds / 60)
    local secs = floor(seconds % 60)
    return format("%02d:%02d", minutes, secs)
end

local function readTime(spec, session)
    if not session then return nil end

    if spec.timesource == "flight" then
        return formatTimeSeconds(session.timer and session.timer.live, false)
    elseif spec.timesource == "count" and session.modelPreferences then
        local value = rfsuite.ini.getvalue(session.modelPreferences, "general", "flightcount")
        return value ~= nil and tostring(value) or nil
    elseif spec.timesource == "total" and session.modelPreferences then
        local value = rfsuite.ini.getvalue(session.modelPreferences, "general", "totalflighttime")
        return formatTimeSeconds(value, true)
    end

    return nil
end

local function readSpec(box, spec, telemetry, slotKey)
    if spec == nil then return nil, nil, nil end

    local session = rfsuite.session or {}
    local kind = spec.kind or "telemetry"
    local rawValue, displayValue, dynamicUnit, thresholds = nil, nil, nil, spec.thresholds

    if kind == "telemetry" then
        rawValue, _, dynamicUnit, _, _, thresholds = readTelemetry(spec, telemetry)
        if spec.source == "temp_esc" then updateEscTempTracker(telemetry, rawValue) end
        if rawValue ~= nil then displayValue = spec.transformFn(rawValue) end
    elseif kind == "tracked_max_esc_temp" then
        rawValue, dynamicUnit, thresholds = readTrackedEscTempMax(spec, telemetry)
        if rawValue ~= nil then displayValue = spec.transformFn(rawValue) end
    elseif kind == "stats" then
        rawValue, dynamicUnit, thresholds = readStats(spec, telemetry)
        if rawValue ~= nil then displayValue = spec.transformFn(rawValue) end
    elseif kind == "watts" then
        local wattsMode = spec.wattsmode or "current"
        rawValue = wattsMode == "current" and currentWatts(telemetry) or statsWatts(telemetry, wattsMode)
        dynamicUnit = "W"
        if rawValue ~= nil then displayValue = spec.transformFn(rawValue) end
    elseif kind == "governor" then
        displayValue = readGovernor(telemetry)
        rawValue = displayValue
    elseif kind == "armflags" then
        displayValue = readArmflags(telemetry, spec.showReason)
        rawValue = displayValue
    elseif kind == "craftname" then
        displayValue = session.craftName or (model and model.name and model.name()) or nil
        rawValue = displayValue
    elseif kind == "tailrpm" then
        -- V6 fallback: if RotorFlight does not expose a dedicated tail RPM sensor,
        -- derive it from main headspeed using the configured tail ratio.
        -- Bell 222UT ratio currently uses 3.82.
        rawValue = telemetry and telemetry.getSensor and telemetry.getSensor(spec.source or "tailspeed")
        if rawValue == nil then
            local mainRpm = telemetry and telemetry.getSensor and telemetry.getSensor("rpm")
            if mainRpm ~= nil then rawValue = mainRpm * (spec.ratio or 3.82) end
        end
        if rawValue ~= nil then displayValue = spec.transformFn(rawValue) end
    elseif kind == "current_alias" then
        rawValue = readCurrentAlias(telemetry)
        dynamicUnit = "A"
        if rawValue ~= nil then displayValue = spec.transformFn(rawValue) end
    elseif kind == "time" then
        displayValue = readTime(spec, session)
        rawValue = displayValue
    elseif kind == "session" then
        if spec.sessionkey then
            displayValue = session[spec.sessionkey]
            rawValue = displayValue
        end
    else
        displayValue = spec.value
        rawValue = displayValue
    end

    local cacheKey = slotKey and ("_lastValid_" .. slotKey) or "_lastValid"

    if displayValue ~= nil and displayValue ~= "" then
        box[cacheKey] = displayValue
    elseif box[cacheKey] ~= nil then
        displayValue = box[cacheKey]
    else
        displayValue = spec.novalue or utils.getPulsingDots(box, slotKey and ("_dots_" .. slotKey) or nil)
    end

    local unit = resolveTelemetryUnit(spec, dynamicUnit, telemetry)
    if rawValue == nil and kind ~= "static" then unit = nil end
    if type(displayValue) == "string" and displayValue:match("^%.+$") then unit = nil end

    local textValueForThreshold = rawValue
    if kind == "governor" or kind == "armflags" or kind == "craftname" or kind == "time" or kind == "static" then
        textValueForThreshold = displayValue
    end

    local textcolor = resolveThresholdColor(textValueForThreshold, spec.textcolor, thresholds, "textcolor")
    return displayValue, unit, textcolor
end

local function paintFillRect(x, y, w, h, box)
    x, y = utils.applyOffset(x, y, box)
    lcd.color(box.color)
    lcd.drawFilledRectangle(x, y, w, h)
end

local function wakeSectionHeader(box)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "sectionheader" then
        cache = {
            _mode = "sectionheader",
            label = box.label or box.value or "",
            font = utils.resolveFont(box.font, utils.resolveFont("FONT_L", nil)),
            textcolor = utils.resolveThemeColor("textcolor", box.textcolor),
            linecolor = utils.resolveThemeColor("textcolor", box.linecolor or box.textcolor),
            bgcolor = utils.resolveThemeColor("bgcolor", box.bgcolor),
            align = box.align or "center",
            lineheight = box.lineheight or 3,
            linewidth = box.linewidth or 1,
            linealign = box.linealign or box.align or "center",
            liney = box.liney or 0.82,
            textband = box.textband or 0.65
        }
        box._cache = cache
    end
    return cache
end

local function paintSectionHeader(x, y, w, h, box, cache)
    if type(cache) ~= "table" or cache._mode ~= "sectionheader" then
        cache = box and box._cache
        if type(cache) ~= "table" then return end
        if cache._mode ~= "sectionheader" then return end
    end

    x, y = utils.applyOffset(x, y, box)
    if cache.bgcolor then
        lcd.color(cache.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    local textBandH = floor(h * cache.textband + 0.5)
    local font, tw, th = pickFont(cache.font, cache.label, w - 8, textBandH)
    lcd.font(font)

    local tx = x + (w - tw) / 2
    if cache.align == "left" then
        tx = x + 2
    elseif cache.align == "right" then
        tx = x + w - tw - 2
    end

    lcd.color(cache.textcolor)
    lcd.drawText(tx, y + floor((textBandH - th) / 2 + 0.5), cache.label)

    local lineW = w
    if type(cache.linewidth) == "number" then
        if cache.linewidth > 0 and cache.linewidth <= 1 then
            lineW = max(1, floor(w * cache.linewidth + 0.5))
        elseif cache.linewidth > 1 then
            lineW = max(1, floor(cache.linewidth + 0.5))
            if lineW > w then lineW = w end
        end
    end

    local lineX = x + floor((w - lineW) / 2 + 0.5)
    if cache.linealign == "left" then
        lineX = x
    elseif cache.linealign == "right" then
        lineX = x + w - lineW
    end

    lcd.color(cache.linecolor)
    lcd.drawFilledRectangle(lineX, y + floor(h * cache.liney + 0.5), lineW, cache.lineheight)
end

local function wakeFitValue(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "fitvalue" then
        cache = {
            _mode = "fitvalue",
            kind = box.kind or "craftname",
            source = box.source,
            stattype = box.stattype,
            wattsmode = box.wattsmode,
            timesource = box.timesource,
            value = box.value,
            unit = box.unit,
            decimals = box.decimals,
            transform = box.transform,
            transformFn = compileTransform(box.transform, box.decimals),
            novalue = box.novalue or "MODEL",
            thresholds = box.thresholds,
            showReason = box.showReason,
            font = utils.resolveFont(box.font, utils.resolveFont("FONT_XL", utils.resolveFont("FONT_L", nil))),
            textcolor = utils.resolveThemeColor("textcolor", box.textcolor),
            bgcolor = utils.resolveThemeColor("bgcolor", box.bgcolor),
            align = box.align or "center",
            padding = box.padding or 4,
            showunit = box.showunit or false
        }
        box._cache = cache
    end

    cache.displayValue, cache.unitDisplay, cache.displayColor = readSpec(box, cache, telemetry, "fitvalue")
    return cache
end

local function paintFitValue(x, y, w, h, box, cache)
    if type(cache) ~= "table" or cache._mode ~= "fitvalue" then
        cache = box and box._cache
        if type(cache) ~= "table" then return end
        if cache._mode ~= "fitvalue" then return end
    end

    x, y = utils.applyOffset(x, y, box)
    if cache.bgcolor then
        lcd.color(cache.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    local text = tostring(cache.displayValue or "")
    if cache.showunit and cache.unitDisplay and cache.unitDisplay ~= "" then
        text = text .. cache.unitDisplay
    end

    local pad = cache.padding or 4
    local font, tw, th = pickFont(cache.font, text, w - (pad * 2), h - 4)
    lcd.font(font)
    lcd.color(cache.displayColor or cache.textcolor)

    local tx = x + (w - tw) / 2
    if cache.align == "left" then
        tx = x + pad
    elseif cache.align == "right" then
        tx = x + w - pad - tw
    end

    lcd.drawText(tx, y + floor((h - th) / 2 + 0.5), text)
end

local function wakeKeyValue(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "keyvalue" then
        cache = {
            _mode = "keyvalue",
            label = box.label or box.title or "",
            kind = box.kind or "telemetry",
            source = box.source,
            stattype = box.stattype,
            wattsmode = box.wattsmode,
            timesource = box.timesource,
            value = box.value,
            unit = box.unit,
            decimals = box.decimals,
            transform = box.transform,
            transformFn = compileTransform(box.transform, box.decimals),
            novalue = box.novalue,
            thresholds = box.thresholds,
            showReason = box.showReason,
            labelfont = utils.resolveFont(box.labelfont or box.titlefont, utils.resolveFont("FONT_STD", nil)),
            valuefont = utils.resolveFont(box.valuefont or box.font, utils.resolveFont("FONT_L", utils.resolveFont("FONT_STD", nil))),
            labelcolor = utils.resolveThemeColor("titlecolor", box.labelcolor or box.titlecolor),
            textcolor = utils.resolveThemeColor("textcolor", box.textcolor),
            bgcolor = utils.resolveThemeColor("bgcolor", box.bgcolor),
            padding = box.padding or 4,
            gap = box.gap or 8
        }
        box._cache = cache
    end

    cache.displayValue, cache.unitDisplay, cache.displayColor = readSpec(box, cache, telemetry, "readout")
    return cache
end

local function paintKeyValue(x, y, w, h, box, cache)
    if type(cache) ~= "table" or cache._mode ~= "keyvalue" then
        cache = box and box._cache
        if type(cache) ~= "table" then return end
        if cache._mode ~= "keyvalue" then return end
    end

    x, y = utils.applyOffset(x, y, box)
    if cache.bgcolor then
        lcd.color(cache.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    local pad = cache.padding or 4
    local gap = cache.gap or 8
    local labelText = tostring(cache.label or "")
    local valueText = tostring(cache.displayValue or "")
    if cache.unitDisplay and cache.unitDisplay ~= "" then valueText = valueText .. cache.unitDisplay end

    local labelFont, labelW, labelH = pickFont(cache.labelfont, labelText, w * 0.52, h - 2)
    local valueAvailW = w - (pad * 2) - labelW - gap
    local valueFont, valueW, valueH = pickFont(cache.valuefont, valueText, valueAvailW, h - 2)

    lcd.font(labelFont)
    lcd.color(cache.labelcolor)
    lcd.drawText(x + pad, y + floor((h - labelH) / 2 + 0.5), labelText)

    lcd.font(valueFont)
    lcd.color(cache.displayColor or cache.textcolor)
    lcd.drawText(x + w - pad - valueW, y + floor((h - valueH) / 2 + 0.5), valueText)
end

local function rowSpec(box, prefix, defaults)
    return {
        label = box[prefix .. "label"] or defaults.label,
        kind = box[prefix .. "kind"] or defaults.kind,
        source = box[prefix .. "source"] or defaults.source,
        sessionkey = box[prefix .. "sessionkey"] or defaults.sessionkey,
        stattype = box[prefix .. "stattype"] or defaults.stattype,
        wattsmode = box[prefix .. "wattsmode"] or defaults.wattsmode,
        timesource = box[prefix .. "timesource"] or defaults.timesource,
        value = box[prefix .. "value"] or defaults.value,
        unit = box[prefix .. "unit"],
        decimals = box[prefix .. "decimals"],
        transform = box[prefix .. "transform"],
        transformFn = compileTransform(box[prefix .. "transform"], box[prefix .. "decimals"]),
        novalue = box[prefix .. "novalue"],
        thresholds = box[prefix .. "thresholds"],
        textcolor = box[prefix .. "textcolor"],
        showReason = box[prefix .. "showReason"]
    }
end

local function wakeTwoRowPanel(box, telemetry)
    local cache = box._cache
    if type(cache) ~= "table" or cache._mode ~= "tworowpanel" then
        cache = {
            _mode = "tworowpanel",
            bordercolor = utils.resolveThemeColor("textcolor", box.bordercolor),
            linecolor = utils.resolveThemeColor("textcolor", box.linecolor or box.bordercolor),
            labelcolor = utils.resolveThemeColor("textcolor", box.labelcolor),
            bgcolor = utils.resolveThemeColor("bgcolor", box.bgcolor),
            border = box.border or 3,
            padding = box.padding or 10,
            gap = box.gap or 10,
            labelfont = utils.resolveFont(box.labelfont, utils.resolveFont("FONT_STD", nil)),
            valuefont = utils.resolveFont(box.valuefont, utils.resolveFont("FONT_STD", nil)),
            row1 = rowSpec(box, "row1", {label = "GOV", kind = "governor"}),
            row2 = rowSpec(box, "row2", {label = "RATE", kind = "telemetry", source = "rate_profile"})
        }
        box._cache = cache
    end

    cache.row1Value, cache.row1Unit, cache.row1Color = readSpec(box, cache.row1, telemetry, "panel1")
    cache.row2Value, cache.row2Unit, cache.row2Color = readSpec(box, cache.row2, telemetry, "panel2")
    return cache
end

local function drawPanelRow(x, y, w, h, label, value, unit, labelFont, valueFont, labelColor, valueColor, pad, gap)
    local labelText = tostring(label or "")
    local valueText = tostring(value or "")
    if unit and unit ~= "" then valueText = valueText .. unit end

    local lFont, lW, lH = pickFont(labelFont, labelText, w * 0.35, h - 2)
    local valueAvailW = w - (pad * 2) - lW - gap
    local vFont, vW, vH = pickFont(valueFont, valueText, valueAvailW, h - 2)

    lcd.font(lFont)
    lcd.color(labelColor)
    lcd.drawText(x + pad, y + floor((h - lH) / 2 + 0.5), labelText)

    lcd.font(vFont)
    lcd.color(valueColor)
    lcd.drawText(x + w - pad - vW, y + floor((h - vH) / 2 + 0.5), valueText)
end

local function paintTwoRowPanel(x, y, w, h, box, cache)
    if type(cache) ~= "table" or cache._mode ~= "tworowpanel" then
        cache = box and box._cache
        if type(cache) ~= "table" then return end
        if cache._mode ~= "tworowpanel" then return end
    end

    x, y = utils.applyOffset(x, y, box)
    if cache.bgcolor then
        lcd.color(cache.bgcolor)
        lcd.drawFilledRectangle(x, y, w, h)
    end

    lcd.color(cache.bordercolor)
    lcd.drawRectangle(x, y, w, h, cache.border)

    local midY = y + floor(h / 2 + 0.5)
    lcd.color(cache.linecolor)
    lcd.drawFilledRectangle(x + cache.border, midY, w - (cache.border * 2), 2)

    local innerX = x + cache.border
    local innerY = y + cache.border
    local innerW = w - (cache.border * 2)
    local innerH = h - (cache.border * 2)
    local rowH = floor(innerH / 2)

    drawPanelRow(innerX, innerY, innerW, rowH, cache.row1.label, cache.row1Value, cache.row1Unit, cache.labelfont, cache.valuefont, cache.labelcolor, cache.row1Color or cache.row1.textcolor, cache.padding, cache.gap)
    drawPanelRow(innerX, innerY + rowH, innerW, innerH - rowH, cache.row2.label, cache.row2Value, cache.row2Unit, cache.labelfont, cache.valuefont, cache.labelcolor, cache.row2Color or cache.row2.textcolor, cache.padding, cache.gap)
end

function common.getOptions(W)
    return themeOptions[utils.getDashboardThemeOptionKey(W)] or themeOptions.ms_std
end

function common.getContentWindow()
    local W, H = lcd.getWindowSize()
    local headerH = 0
    if utils.isFullScreen(W, H) then
        headerH = common.headerLayout.height or 0
        H = H - headerH
    end
    return W, H, headerH
end

function common.headerBoxes(cache)
    local txbatt_type = 0
    local signature = utils.getThemeSignature()
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    if cache.boxes == nil or cache.txbatt_type ~= txbatt_type or cache.theme_signature ~= signature then
        cache.boxes = utils.standardHeaderBoxes(i18n, common.getHeaderColorMode(), utils.getHeaderOptions(), txbatt_type)
        cache.txbatt_type = txbatt_type
        cache.theme_signature = signature
    end

    return cache.boxes
end

local function rect(x, y, w, h, box)
    box = box or {}
    box.x = round(x)
    box.y = round(y)
    box.w = max(1, round(w))
    box.h = max(1, round(h))
    return box
end

local function area(W, H, xp, yp, wp, hp)
    return W * xp, H * yp, W * wp, H * hp
end

local function rectPct(W, H, xp, yp, wp, hp, box)
    local x, y, w, h = area(W, H, xp, yp, wp, hp)
    return rect(x, y, w, h, box)
end

local function add(out, box)
    out[#out + 1] = box
end

local function extend(box, extra)
    if extra ~= nil then
        for k, v in pairs(extra) do
            box[k] = v
        end
    end
    return box
end

local function widgetBox(W, H, xp, yp, wp, hp, boxType, subtype, props)
    local box = props or {}
    box.type = boxType
    box.subtype = subtype
    return rectPct(W, H, xp, yp, wp, hp, box)
end

local function backgroundBox(W, H, color)
    return widgetBox(W, H, 0, 0, 1, 1, "text", "text", {
        value = "",
        novalue = "",
        bgcolor = color
    })
end

local function labelBox(W, H, xp, yp, wp, hp, value, font, color, align, bgcolor)
    return widgetBox(W, H, xp, yp, wp, hp, "text", "text", {
        value = value,
        novalue = "",
        font = font,
        textcolor = color,
        valuealign = align or "center",
        bgcolor = bgcolor or common.getPalette().bg
    })
end

local function ruleBox(W, H, xp, yp, wp, hp, color)
    return widgetBox(W, H, xp, yp, wp, hp, "func", "func", {
        color = color,
        paint = paintFillRect
    })
end

local function sectionBox(W, H, xp, yp, wp, hp, label, font, color, align, extra)
    return widgetBox(W, H, xp, yp, wp, hp, "func", "func", extend({
        label = label,
        font = font,
        textcolor = color,
        linecolor = color,
        align = align or "center",
        bgcolor = common.getPalette().bg,
        wakeup = wakeSectionHeader,
        paint = paintSectionHeader
    }, extra))
end

local function fitValueBox(W, H, xp, yp, wp, hp, font, color, extra)
    return widgetBox(W, H, xp, yp, wp, hp, "func", "func", extend({
        kind = "craftname",
        font = font,
        textcolor = color,
        bgcolor = common.getPalette().bg,
        wakeup = wakeFitValue,
        paint = paintFitValue
    }, extra))
end

local function readoutBox(W, H, xp, yp, wp, hp, label, labelFont, valueFont, labelColor, valueColor, extra)
    return widgetBox(W, H, xp, yp, wp, hp, "func", "func", extend({
        label = label,
        labelfont = labelFont,
        valuefont = valueFont,
        labelcolor = labelColor,
        textcolor = valueColor,
        bgcolor = common.getPalette().bg,
        wakeup = wakeKeyValue,
        paint = paintKeyValue
    }, extra))
end

local function statusPanelBox(W, H, xp, yp, wp, hp, labelFont, valueFont, borderColor, extra)
    return widgetBox(W, H, xp, yp, wp, hp, "func", "func", extend({
        bordercolor = borderColor,
        linecolor = borderColor,
        labelcolor = borderColor,
        labelfont = labelFont,
        valuefont = valueFont,
        bgcolor = common.getPalette().bg,
        wakeup = wakeTwoRowPanel,
        paint = paintTwoRowPanel
    }, extra))
end

local function titledValueBox(W, H, xp, yp, wp, hp, boxType, subtype, title, titleFont, valueFont, titleColor, valueColor, extra)
    return widgetBox(W, H, xp, yp, wp, hp, boxType, subtype, extend({
        title = title,
        titlepos = "top",
        titlealign = "center",
        titlefont = titleFont,
        titlecolor = titleColor,
        font = valueFont,
        textcolor = valueColor,
        bgcolor = common.getPalette().bg
    }, extra))
end

function common.buildCockpitBoxes()
    local W, H = common.getContentWindow()
    local opts = common.getOptions(W)
    local p = common.getPalette()
    local hcm = common.getHeaderColorMode()
    local out = {}

    local lineH = max(2, round(H * 0.005))
    local frameT = max(2, round(H * 0.005))
    local readoutPad = max(5, round(W * 0.008))
    local readoutGap = max(5, round(W * 0.008))

    add(out, backgroundBox(W, H, p.bg))

    -- HeliHUD PRE-FLIGHT: battery/readiness only. No RPM here.
    add(out, fitValueBox(W, H, 0.03, 0.03, 0.24, 0.08, opts.craftnamefont, p.white, {
        kind = "craftname", novalue = "BELL 222UT", align = "left", padding = 2
    }))
    add(out, labelBox(W, H, 0.36, 0.03, 0.28, 0.08, "PREFLIGHT", opts.bannerfont, p.green, "center", p.bg))
    add(out, widgetBox(W, H, 0.78, 0.04, 0.18, 0.07, "text", "armflags", {
        font = opts.statusfont, valuealign = "center", bgcolor = p.bg,
        textcolor = p.green,
        thresholds = {
            {value = "ARMED", textcolor = p.yellow},
            {value = "DISARMED", textcolor = p.green}
        }
    }))

    -- large center Smart Fuel / battery arc
    add(out, widgetBox(W, H, 0.29, 0.17, 0.42, 0.48, "gauge", "arc", {
        source = "smartfuel", transform = "floor", unit = "%",
        min = 0, max = 100, thickness = max(18, round(H * 0.075)),
        font = opts.bigfont, title = "SMART FUEL", titlepos = "top", titlealign = "center",
        titlefont = opts.headingfont, valuepaddingtop = max(12, round(H * 0.05)),
        fillcolor = p.blue or p.line, fillbgcolor = p.dim, accentcolor = p.blue or p.line,
        textcolor = p.white, titlecolor = p.white, bgcolor = p.bg,
        thresholds = {
            {value = 15, fillcolor = hcm.fillcritcolor, textcolor = p.white},
            {value = 40, fillcolor = p.yellow, textcolor = p.white},
            {value = 100, fillcolor = p.blue or p.line, textcolor = p.white}
        }
    }))

    -- left battery stack
    add(out, readoutBox(W, H, 0.05, 0.24, 0.20, 0.11, "BATTERY", opts.leftlabelfont, opts.rightvaluefont, p.white, p.blue, {
        kind = "telemetry", source = "voltage", decimals = 2, unit = "V", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.05, 0.41, 0.20, 0.10, "CELL", opts.leftlabelfont, opts.leftvaluefont, p.white, p.blue, {
        kind = "telemetry", source = "voltage", decimals = 2, unit = "V", transform = maxVoltageToCellVoltage,
        padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.05, 0.56, 0.20, 0.10, "BEC", opts.leftlabelfont, opts.leftvaluefont, p.white, p.white, {
        kind = "telemetry", source = "bec_voltage", decimals = 2, unit = "V", padding = readoutPad, gap = readoutGap
    }))

    -- right health/status stack
    add(out, readoutBox(W, H, 0.75, 0.24, 0.20, 0.10, "ESC TEMP", opts.leftlabelfont, opts.leftvaluefont, p.white, p.green, {
        kind = "telemetry", source = "temp_esc", transform = "floor", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.75, 0.39, 0.20, 0.10, "LINK", opts.leftlabelfont, opts.leftvaluefont, p.white, p.blue, {
        kind = "telemetry", source = "link", transform = "floor", unit = "dB", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.75, 0.54, 0.20, 0.10, "VFR", opts.leftlabelfont, opts.leftvaluefont, p.white, p.blue, {
        kind = "telemetry", source = "vfr", transform = "floor", unit = "%", padding = readoutPad, gap = readoutGap
    }))

    -- profile/readiness row
    add(out, readoutBox(W, H, 0.07, 0.75, 0.20, 0.10, "BATT PROF", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        kind = "telemetry", source = "battery_profile", transform = "floor", padding = readoutPad, gap = 4
    }))
    add(out, readoutBox(W, H, 0.30, 0.75, 0.18, 0.10, "PID", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        kind = "telemetry", source = "pid_profile", transform = "floor", padding = readoutPad, gap = 4
    }))
    add(out, readoutBox(W, H, 0.50, 0.75, 0.18, 0.10, "RATE", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        kind = "telemetry", source = "rate_profile", transform = "floor", padding = readoutPad, gap = 4
    }))
    add(out, widgetBox(W, H, 0.72, 0.74, 0.22, 0.12, "text", "armflags", {
        font = opts.statusfont, valuealign = "center", bgcolor = p.bg, textcolor = p.green,
        thresholds = {
            {value = "ARMED", textcolor = p.yellow},
            {value = "DISARMED", textcolor = p.green}
        }
    }))
    add(out, labelBox(W, H, 0.35, 0.88, 0.30, 0.08, "READY TO FLY", opts.statusfont, p.green, "center", p.bg))

    return out
end

function common.buildInflightBoxes()
    local W, H = common.getContentWindow()
    local opts = common.getOptions(W)
    local p = common.getPalette()
    local hcm = common.getHeaderColorMode()
    local out = {}

    local lineH = max(2, round(H * 0.005))
    local readoutPad = max(5, round(W * 0.007))
    local readoutGap = max(5, round(W * 0.008))
    local arcT = max(12, round(H * 0.050))
    local bigArcT = max(16, round(H * 0.065))

    add(out, backgroundBox(W, H, p.bg))

    -- Header strip
    add(out, fitValueBox(W, H, 0.03, 0.02, 0.25, 0.08, opts.craftnamefont, p.white, {
        kind = "craftname", novalue = "BELL 222UT", align = "left", padding = 2
    }))
    add(out, labelBox(W, H, 0.435, 0.022, 0.13, 0.050, "HeliHUD", opts.headingfont, p.white, "center", p.bg))
    add(out, labelBox(W, H, 0.555, 0.038, 0.05, 0.035, "PRO", opts.bottomtitlefont, p.line, "center", p.bg))
    add(out, readoutBox(W, H, 0.78, 0.025, 0.17, 0.07, "FUEL", opts.bottomtitlefont, opts.bottomvaluefont, p.white, p.blue, {
        kind = "telemetry", source = "smartfuel", transform = "floor", unit = "%", padding = readoutPad, gap = 4
    }))

    -- V5: self-explanatory arc labels removed. The gauges and units do the talking.

    -- Fuel arc
    add(out, widgetBox(W, H, 0.05, 0.17, 0.24, 0.34, "gauge", "arc", {
        source = "smartfuel", transform = "floor", unit = "%", min = 0, max = 100,
        thickness = arcT, font = opts.rightvaluefont, valuepaddingtop = max(8, round(H * 0.03)),
        fillcolor = p.blue or p.line, fillbgcolor = p.dim, textcolor = p.white, titlecolor = p.white, bgcolor = p.bg,
        thresholds = {{value = 15, fillcolor = hcm.fillcritcolor}, {value = 40, fillcolor = p.yellow}, {value = 100, fillcolor = p.blue or p.line}}
    }))

    -- Headspeed arc 1500-1900 with 1840 normal target headroom
    add(out, widgetBox(W, H, 0.30, 0.105, 0.40, 0.39, "gauge", "arc", {
        source = "rpm", transform = "floor", unit = "", novalue = "-", min = 1500, max = 1900,
        thickness = bigArcT, font = opts.bigfont, valuepaddingtop = max(6, round(H * 0.025)),
        fillcolor = p.line, fillbgcolor = p.dim, textcolor = p.white, titlecolor = p.line, bgcolor = p.bg
    }))
    add(out, labelBox(W, H, 0.46, 0.455, 0.08, 0.05, "RPM", opts.biglabelfont, p.line, "center", p.bg))

    -- ESC output arc. Source matches RotorFlight telemetry sensor Throttle %.
    add(out, widgetBox(W, H, 0.74, 0.17, 0.24, 0.34, "gauge", "arc", {
        source = "throttle_percent", transform = "floor", unit = "%", min = 0, max = 100,
        thickness = arcT, font = opts.rightvaluefont, valuepaddingtop = max(8, round(H * 0.03)),
        fillcolor = p.line, fillbgcolor = p.dim, textcolor = p.white, titlecolor = p.white, bgcolor = p.bg,
        thresholds = {{value = 70, fillcolor = p.line}, {value = 85, fillcolor = p.yellow}, {value = 100, fillcolor = hcm.fillcritcolor}}
    }))

    -- ACTIVE center status ribbon
    add(out, labelBox(W, H, 0.39, 0.515, 0.22, 0.075, "ACTIVE", opts.statusfont, p.green, "center", p.bg))

    -- Mid row values
    add(out, readoutBox(W, H, 0.08, 0.66, 0.20, 0.12, "CELL", opts.bottomtitlefont, opts.rightvaluefont, p.white, p.blue, {
        kind = "telemetry", source = "voltage", decimals = 2, unit = "V", transform = maxVoltageToCellVoltage, padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.39, 0.66, 0.22, 0.12, "CURRENT", opts.bottomtitlefont, opts.rightvaluefont, p.white, p.white, {
        kind = "current_alias", source = "current", decimals = 1, unit = "A", novalue = "--", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.72, 0.66, 0.22, 0.12, "ESC TEMP", opts.bottomtitlefont, opts.rightvaluefont, p.white, p.green, {
        kind = "telemetry", source = "temp_esc", transform = "floor", padding = readoutPad, gap = readoutGap,
        thresholds = {{value = 140, textcolor = p.green}, {value = 165, textcolor = p.yellow}, {value = 230, textcolor = p.red}}
    }))


    -- Bottom row
    add(out, readoutBox(W, H, 0.08, 0.84, 0.22, 0.11, "TAIL RPM", opts.bottomtitlefont, opts.bottomvaluefont, p.white, p.white, {
        kind = "tailrpm", source = "tailspeed", ratio = 3.82, transform = "floor", unit = "", novalue = "--", padding = readoutPad, gap = 4
    }))
    add(out, titledValueBox(W, H, 0.39, 0.84, 0.22, 0.11, "time", "flight", "TIMER", opts.bottomtitlefont, opts.bottomvaluefont, p.white, p.white, {
        titlespacing = max(8, round(H * 0.02))
    }))
    add(out, readoutBox(W, H, 0.70, 0.84, 0.24, 0.11, "LINK", opts.bottomtitlefont, opts.bottomvaluefont, p.white, p.blue, {
        kind = "telemetry", source = "link", transform = "floor", unit = "dB", padding = readoutPad, gap = 4
    }))

    return out
end

function common.buildReportBoxes()
    local W, H = common.getContentWindow()
    local opts = common.getOptions(W)
    local p = common.getPalette()
    local out = {}

    local readoutPad = max(5, round(W * 0.008))
    local readoutGap = max(5, round(W * 0.010))

    add(out, backgroundBox(W, H, p.bg))

    add(out, labelBox(W, H, 0.03, 0.035, 0.20, 0.065, "HeliHUD", opts.craftnamefont, p.white, "left", p.bg))
    add(out, labelBox(W, H, 0.36, 0.03, 0.30, 0.08, "FLIGHT REPORT", opts.bannerfont, p.line, "center", p.bg))
    add(out, widgetBox(W, H, 0.74, 0.04, 0.22, 0.07, "text", "armflags", {
        font = opts.statusfont, valuealign = "center", bgcolor = p.bg, textcolor = p.green,
        thresholds = {{value = "ARMED", textcolor = p.yellow}, {value = "DISARMED", textcolor = p.green}}
    }))

    -- Left column power/battery summary
    add(out, readoutBox(W, H, 0.07, 0.21, 0.36, 0.08, "FLIGHT TIME", opts.leftlabelfont, opts.leftvaluefont, p.white, p.white, {
        kind = "time", timesource = "flight", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.07, 0.32, 0.36, 0.08, "FUEL REMAIN", opts.leftlabelfont, opts.leftvaluefont, p.white, p.blue, {
        kind = "telemetry", source = "smartfuel", transform = "floor", unit = "%", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.07, 0.43, 0.36, 0.08, "mAh USED", opts.leftlabelfont, opts.leftvaluefont, p.white, p.white, {
        kind = "stats", stattype = "max", source = "smartconsumption", transform = "floor", unit = "mAh", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.07, 0.54, 0.36, 0.08, "LOWEST CELL", opts.leftlabelfont, opts.leftvaluefont, p.white, p.yellow, {
        kind = "stats", stattype = "min", source = "voltage", transform = maxVoltageToCellVoltage, decimals = 2, unit = "V", padding = readoutPad, gap = readoutGap
    }))

    -- Right column max values
    add(out, readoutBox(W, H, 0.56, 0.21, 0.36, 0.08, "MAX CURRENT", opts.leftlabelfont, opts.leftvaluefont, p.white, p.white, {
        kind = "stats", stattype = "max", source = "current", decimals = 1, unit = "A", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.56, 0.32, 0.36, 0.08, "MAX ESC TEMP", opts.leftlabelfont, opts.leftvaluefont, p.white, p.white, {
        kind = "tracked_max_esc_temp", source = "temp_esc", transform = "floor", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.56, 0.43, 0.36, 0.08, "MAX RPM", opts.leftlabelfont, opts.leftvaluefont, p.white, p.white, {
        kind = "stats", stattype = "max", source = "rpm", transform = "floor", unit = "RPM", padding = readoutPad, gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.56, 0.54, 0.36, 0.08, "MIN LINK", opts.leftlabelfont, opts.leftvaluefont, p.white, p.blue, {
        kind = "stats", stattype = "min", source = "link", transform = "floor", unit = "dB", padding = readoutPad, gap = readoutGap
    }))

    add(out, labelBox(W, H, 0.16, 0.73, 0.22, 0.10, "BLACKBOX", opts.statusfont, p.line, "center", p.bg))
    add(out, readoutBox(W, H, 0.39, 0.73, 0.22, 0.10, "USED", opts.bottomtitlefont, opts.bottomvaluefont, p.white, p.white, {
        kind = "telemetry", source = "bbl_used", transform = "floor", padding = readoutPad, gap = 4
    }))
    add(out, labelBox(W, H, 0.64, 0.73, 0.22, 0.10, "FLIGHT OK", opts.statusfont, p.green, "center", p.bg))

    add(out, labelBox(W, H, 0.22, 0.88, 0.56, 0.07, "HeliHUD PRO V8  —  Every pixel has a purpose.", opts.bottomtitlefont, p.line, "center", p.bg))

    return out
end

return common
