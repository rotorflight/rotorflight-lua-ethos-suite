--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local model = model

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
    bg = rgb(10, 10, 10),
    bgalt = rgb(16, 16, 16),
    line = rgb(0, 225, 255),
    green = rgb(34, 236, 22),
    white = rgb(245, 245, 245),
    yellow = rgb(255, 229, 0),
    red = rgb(224, 64, 64),
    dim = rgb(56, 56, 56)
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
    local signature = utils.getThemeSignature()
    if paletteCache.palette and paletteCache.signature == signature then return paletteCache.palette end

    local state = utils.getThemeState() or {}
    local colorMode = utils.themeColors()
    local base = common.basePalette
    local useSystemAccent = state.usesThemeColors == true

    local palette = {
        bg = colorMode.bgcolor or base.bg,
        bgalt = colorMode.paneldarkbg or colorMode.fillbgcolor or base.bgalt,
        line = (useSystemAccent and (state.mixerOutputColor or colorMode.titlecolor)) or colorMode.titlecolor or base.line,
        green = state.safeColor or colorMode.fillcolor or base.green,
        power = (useSystemAccent and ((state.mixerOutputColor or colorMode.titlecolor) or base.line)) or (state.safeColor or colorMode.fillcolor or base.green),
        white = colorMode.textcolor or base.white,
        yellow = state.warningColor or colorMode.fillwarncolor or base.yellow,
        red = state.errorColor or colorMode.fillcritcolor or base.red,
        dim = colorMode.panelbgline or state.buttonBorderColor or colorMode.accentcolor or base.dim
    }

    paletteCache.signature = signature
    paletteCache.palette = palette
    paletteCache.headerColorMode = {
        fillwarncolor = palette.yellow,
        fillcolor = palette.power,
        fillcritcolor = palette.red,
        tbbgcolor = colorMode.tbbgcolor or palette.bg,
        tbtextcolor = colorMode.tbtextcolor or palette.white,
        titlecolor = palette.line,
        txbgfillcolor = colorMode.txbgfillcolor or palette.bgalt,
        txaccentcolor = palette.line,
        txfillcolor = palette.power,
        cntextcolor = colorMode.cntextcolor or palette.white,
        rssitextcolor = colorMode.rssitextcolor or palette.white,
        rssifillcolor = palette.power,
        rssifillbgcolor = colorMode.rssifillbgcolor or palette.bgalt
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
    if value == 1 or value == 3 then return "@i18n(widgets.governor.ARMED)@" end
    return "@i18n(widgets.governor.DISARMED)@"
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
    local leftColumnX, leftColumnW = 0.03, 0.30
    local centerColumnX, centerColumnW = 0.35, 0.31
    local rightColumnX, rightColumnW = 0.76, 0.19

    local lineH = max(2, round(H * 0.006))
    local frameT = max(2, round(H * 0.005))
    local readoutPad = max(4, round(W * 0.006))
    local readoutGap = max(6, round(W * 0.010))
    local compactReadoutGap = max(4, round(W * 0.006))
    local panelPad = max(8, round(W * 0.012))
    local stackTitleSpacing = max(10, round(H * 0.022))
    local stackValueTop = max(10, round(H * 0.017))
    local heroTitleSpacing = max(18, round(H * 0.040))
    local heroValueTop = max(18, round(H * 0.030))
    local midLowerShift = 0.025
    local profileRowW = 0.27
    local profileSlotGap = 0.006
    local profileSlotW = (profileRowW - profileSlotGap) / 2
    local profilePad = readoutPad + max(2, round(W * 0.004))

    add(out, backgroundBox(W, H, p.bg))

    add(out, sectionBox(W, H, leftColumnX, 0.08, leftColumnW, 0.09, "POWER", opts.headingfont, p.power, "left", {
        lineheight = lineH,
        linewidth = 0.27 / leftColumnW,
        linealign = "left",
        linecolor = p.line
    }))
    add(out, sectionBox(W, H, centerColumnX, 0.08, centerColumnW, 0.09, "HEADSPEED", opts.headingfont, p.line, "center", {
        lineheight = lineH,
        linewidth = 0.18 / centerColumnW
    }))
    add(out, sectionBox(W, H, rightColumnX, 0.08, rightColumnW, 0.09, "TAIL SYSTEM", opts.headingfont, p.line, "center", {
        lineheight = lineH,
        linewidth = 0.14 / rightColumnW
    }))

    add(out, readoutBox(W, H, 0.03, 0.22, 0.27, 0.05, "VOLT", opts.leftlabelfont, opts.leftvaluefont, p.power, p.white, {
        kind = "telemetry",
        source = "voltage",
        decimals = 2,
        unit = "V",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.03, 0.30, 0.27, 0.05, "CURRENT", opts.leftlabelfont, opts.leftvaluefont, p.power, p.white, {
        kind = "telemetry",
        source = "current",
        decimals = 1,
        unit = "A",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.03, 0.38, 0.27, 0.05, "POWER", opts.leftlabelfont, opts.leftvaluefont, p.power, p.white, {
        kind = "watts",
        wattsmode = "current",
        unit = "W",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.03, 0.46, 0.27, 0.05, "SMART FUEL", opts.leftlabelfont, opts.leftvaluefont, p.power, p.power, {
        kind = "telemetry",
        source = "smartfuel",
        transform = "floor",
        unit = "%",
        padding = readoutPad,
        gap = max(4, round(W * 0.008))
    }))
    add(out, widgetBox(W, H, 0.03, 0.55 + midLowerShift, 0.28, 0.06, "gauge", "bar", {
        source = "smartfuel",
        min = 0,
        max = 100,
        battery = true,
        batteryframe = false,
        batteryframethickness = frameT,
        batterysegments = 4,
        batteryspacing = max(2, round(W * 0.004)),
        batterysegmentpaddingtop = max(1, round(H * 0.008)),
        batterysegmentpaddingbottom = max(1, round(H * 0.008)),
        batterysegmentpaddingleft = max(1, round(W * 0.005)),
        batterysegmentpaddingright = max(1, round(W * 0.005)),
        hidevalue = true,
        fillcolor = p.power,
        fillbgcolor = p.bgalt,
        accentcolor = p.power,
        bgcolor = p.bg,
        thresholds = {
            {value = 15, fillcolor = hcm.fillcritcolor},
            {value = 40, fillcolor = p.yellow},
            {value = 100, fillcolor = p.power}
        }
    }))
    add(out, readoutBox(W, H, leftColumnX, 0.645 + midLowerShift, profileSlotW, 0.06, "PROFILE", opts.leftlabelfont, opts.profilefont, p.line, p.white, {
        kind = "telemetry",
        source = "pid_profile",
        transform = "floor",
        unit = "",
        padding = profilePad,
        gap = compactReadoutGap
    }))
    add(out, readoutBox(W, H, leftColumnX + profileSlotW + profileSlotGap, 0.645 + midLowerShift, profileSlotW, 0.06, "RATE", opts.leftlabelfont, opts.profilefont, p.line, p.white, {
        kind = "telemetry",
        source = "rate_profile",
        transform = "floor",
        unit = "",
        padding = profilePad,
        gap = compactReadoutGap
    }))

    add(out, widgetBox(W, H, 0.41, 0.25, 0.18, 0.18, "text", "telemetry", {
        source = "rpm",
        transform = "floor",
        unit = "",
        novalue = "-",
        valuealign = "center",
        font = opts.bigfont,
        textcolor = p.white,
        bgcolor = p.bg
    }))
    add(out, labelBox(W, H, 0.46, 0.44, 0.08, 0.05, "RPM", opts.biglabelfont, p.line, "center", p.bg))

    add(out, statusPanelBox(W, H, centerColumnX, 0.53 + midLowerShift, centerColumnW, 0.16, opts.framefont, opts.framefont, p.yellow, {
        border = frameT,
        padding = panelPad,
        gap = readoutGap,
        row1label = "GOV",
        row1kind = "governor",
        row1textcolor = p.yellow,
        row2label = "ERR",
        row2kind = "session",
        row2sessionkey = "headspeedVariancePct",
        row2transform = "round",
        row2unit = "%",
        row2novalue = "--",
        row2textcolor = p.yellow
    }))

    add(out, titledValueBox(W, H, 0.79, 0.26, 0.14, 0.15, "text", "telemetry", "TAIL RPM", opts.biglabelfont, opts.rightvaluefont, p.line, p.white, {
        source = "tailspeed",
        transform = "floor",
        unit = "",
        valuealign = "center",
        titlespacing = heroTitleSpacing,
        titlepaddingbottom = max(2, round(H * 0.006)),
        valuepaddingtop = heroValueTop
    }))
    add(out, labelBox(W, H, 0.77, 0.53 + midLowerShift, 0.16, 0.05, "STATUS", opts.headingfont, p.yellow, "center", p.bg))
    add(out, widgetBox(W, H, rightColumnX, 0.60 + midLowerShift, rightColumnW, 0.07, "text", "armflags", {
        font = opts.statusfont,
        textcolor = p.line,
        valuealign = "center",
        bgcolor = p.bg,
        thresholds = {
            {value = "@i18n(widgets.governor.ARMED)@", textcolor = p.yellow},
            {value = "@i18n(widgets.governor.DISARMED)@", textcolor = p.line}
        }
    }))

    add(out, titledValueBox(W, H, 0.03, 0.82, 0.12, 0.12, "time", "flight", "TIME", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        titlespacing = stackTitleSpacing,
        valuepaddingtop = stackValueTop
    }))
    add(out, titledValueBox(W, H, 0.18, 0.82, 0.14, 0.12, "text", "telemetry", "RSSI", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        source = "link",
        transform = "floor",
        unit = "dB",
        titlespacing = stackTitleSpacing,
        valuepaddingtop = stackValueTop
    }))
    add(out, titledValueBox(W, H, 0.35, 0.82, 0.12, 0.12, "text", "telemetry", "VFR", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        source = "vfr",
        transform = "floor",
        titlespacing = stackTitleSpacing,
        valuepaddingtop = stackValueTop
    }))
    add(out, titledValueBox(W, H, 0.48, 0.82, 0.17, 0.12, "text", "telemetry", "ESC TEMP", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        source = "temp_esc",
        transform = "floor",
        titlespacing = stackTitleSpacing,
        valuepaddingtop = stackValueTop
    }))
    add(out, titledValueBox(W, H, 0.66, 0.82, 0.12, 0.12, "text", "telemetry", "BEC", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        source = "bec_voltage",
        decimals = 2,
        unit = "V",
        titlespacing = stackTitleSpacing,
        valuepaddingtop = stackValueTop
    }))
    add(out, titledValueBox(W, H, 0.81, 0.82, 0.13, 0.12, "text", "telemetry", "CELL", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        source = "voltage",
        decimals = 2,
        unit = "V",
        transform = maxVoltageToCellVoltage,
        titlespacing = stackTitleSpacing,
        valuepaddingtop = stackValueTop
    }))

    return out
end

function common.buildInflightBoxes()
    local W, H = common.getContentWindow()
    local opts = common.getOptions(W)
    local p = common.getPalette()
    local hcm = common.getHeaderColorMode()
    local out = {}

    local lineH = max(2, round(H * 0.006))
    local frameT = max(2, round(H * 0.005))
    local readoutPad = max(6, round(W * 0.010))
    local readoutGap = max(6, round(W * 0.012))
    local panelPad = max(10, round(W * 0.016))

    add(out, backgroundBox(W, H, p.bg))

    add(out, sectionBox(W, H, 0.06, 0.06, 0.25, 0.08, "POWER", opts.headingfont, p.power, "left", {
        lineheight = lineH,
        linewidth = 0.22 / 0.25,
        linealign = "left",
        linecolor = p.line
    }))
    add(out, sectionBox(W, H, 0.34, 0.06, 0.32, 0.08, "HEADSPEED", opts.headingfont, p.line, "center", {
        lineheight = lineH,
        linewidth = 0.22 / 0.32
    }))
    add(out, sectionBox(W, H, 0.71, 0.06, 0.23, 0.08, "STATUS", opts.headingfont, p.yellow, "center", {
        lineheight = lineH,
        linewidth = 0.18 / 0.23,
        linecolor = p.line
    }))

    add(out, readoutBox(W, H, 0.06, 0.26, 0.27, 0.08, "FUEL", opts.leftlabelfont, opts.rightvaluefont, p.power, p.power, {
        kind = "telemetry",
        source = "smartfuel",
        transform = "floor",
        unit = "%",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, widgetBox(W, H, 0.06, 0.39, 0.28, 0.10, "gauge", "bar", {
        source = "smartfuel",
        min = 0,
        max = 100,
        battery = true,
        batteryframe = false,
        batteryframethickness = frameT,
        batterysegments = 4,
        batteryspacing = max(2, round(W * 0.005)),
        batterysegmentpaddingtop = max(1, round(H * 0.010)),
        batterysegmentpaddingbottom = max(1, round(H * 0.010)),
        batterysegmentpaddingleft = max(1, round(W * 0.006)),
        batterysegmentpaddingright = max(1, round(W * 0.006)),
        hidevalue = true,
        fillcolor = p.power,
        fillbgcolor = p.bgalt,
        accentcolor = p.power,
        bgcolor = p.bg,
        thresholds = {
            {value = 15, fillcolor = hcm.fillcritcolor},
            {value = 40, fillcolor = p.yellow},
            {value = 100, fillcolor = p.power}
        }
    }))
    add(out, readoutBox(W, H, 0.06, 0.56, 0.27, 0.07, "CELL", opts.leftlabelfont, opts.leftvaluefont, p.line, p.white, {
        kind = "telemetry",
        source = "voltage",
        decimals = 2,
        unit = "V",
        transform = maxVoltageToCellVoltage,
        padding = readoutPad,
        gap = readoutGap
    }))

    add(out, widgetBox(W, H, 0.36, 0.23, 0.28, 0.26, "text", "telemetry", {
        source = "rpm",
        transform = "floor",
        unit = "",
        novalue = "-",
        valuealign = "center",
        font = opts.bigfont,
        textcolor = p.white,
        bgcolor = p.bg
    }))
    add(out, labelBox(W, H, 0.44, 0.49, 0.12, 0.06, "RPM", opts.biglabelfont, p.line, "center", p.bg))

    add(out, readoutBox(W, H, 0.70, 0.26, 0.25, 0.07, "TIME", opts.leftlabelfont, opts.leftvaluefont, p.line, p.white, {
        kind = "time",
        timesource = "flight",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.70, 0.43, 0.25, 0.07, "LINK", opts.leftlabelfont, opts.leftvaluefont, p.line, p.white, {
        kind = "telemetry",
        source = "link",
        transform = "floor",
        unit = "dB",
        padding = readoutPad,
        gap = readoutGap
    }))

    add(out, statusPanelBox(W, H, 0.34, 0.68, 0.32, 0.17, opts.framefont, opts.framefont, p.yellow, {
        border = frameT,
        padding = panelPad,
        gap = readoutGap,
        row1label = "GOV",
        row1kind = "governor",
        row1textcolor = p.yellow,
        row2label = "ERR",
        row2kind = "session",
        row2sessionkey = "headspeedVariancePct",
        row2transform = "round",
        row2unit = "%",
        row2novalue = "--",
        row2textcolor = p.yellow
    }))
    return out
end

function common.buildReportBoxes()
    local W, H = common.getContentWindow()
    local opts = common.getOptions(W)
    local p = common.getPalette()
    local out = {}

    local lineH = max(2, round(H * 0.006))
    local frameT = max(2, round(H * 0.005))
    local readoutPad = max(4, round(W * 0.006))
    local readoutGap = max(6, round(W * 0.010))
    local panelPad = max(8, round(W * 0.012))
    local titleGap = max(14, round(H * 0.034))

    add(out, backgroundBox(W, H, p.bg))

    add(out, sectionBox(W, H, 0.03, 0.04, 0.23, 0.09, "POWER", opts.headingfont, p.power, "left", {
        lineheight = lineH,
        linecolor = p.line
    }))
    add(out, sectionBox(W, H, 0.36, 0.04, 0.24, 0.09, "FLIGHT TIME", opts.headingfont, p.line, "center", {
        lineheight = lineH
    }))
    add(out, sectionBox(W, H, 0.75, 0.04, 0.20, 0.09, "STATUS", opts.headingfont, p.line, "center", {
        lineheight = lineH
    }))

    add(out, readoutBox(W, H, 0.03, 0.25, 0.26, 0.05, "MIN CELL", opts.leftlabelfont, opts.leftvaluefont, p.power, p.white, {
        kind = "stats",
        stattype = "min",
        source = "voltage",
        transform = maxVoltageToCellVoltage,
        unit = "V",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.03, 0.33, 0.26, 0.05, "MAX CURR", opts.leftlabelfont, opts.leftvaluefont, p.power, p.white, {
        kind = "stats",
        stattype = "max",
        source = "current",
        decimals = 1,
        unit = "A",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.03, 0.41, 0.26, 0.05, "MAX PWR", opts.leftlabelfont, opts.leftvaluefont, p.power, p.white, {
        kind = "watts",
        wattsmode = "max",
        unit = "W",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.03, 0.49, 0.26, 0.05, "USED", opts.leftlabelfont, opts.leftvaluefont, p.power, p.power, {
        kind = "stats",
        stattype = "max",
        source = "smartconsumption",
        transform = "floor",
        unit = "mAh",
        padding = readoutPad,
        gap = readoutGap
    }))
    add(out, readoutBox(W, H, 0.03, 0.58, 0.26, 0.05, "FLIGHTS", opts.leftlabelfont, opts.leftvaluefont, p.line, p.white, {
        kind = "time",
        timesource = "count",
        unit = "",
        padding = readoutPad,
        gap = readoutGap
    }))

    add(out, titledValueBox(W, H, 0.40, 0.25, 0.21, 0.24, "time", "flight", "LAST FLIGHT", opts.biglabelfont, opts.bigfont, p.line, p.white, {
        titlespacing = titleGap
    }))

    add(out, statusPanelBox(W, H, 0.35, 0.57, 0.30, 0.17, opts.framefont, opts.framefont, p.yellow, {
        border = frameT,
        padding = panelPad,
        gap = readoutGap,
        row1label = "RPM",
        row1kind = "stats",
        row1stattype = "max",
        row1source = "rpm",
        row1transform = "floor",
        row1unit = "",
        row1textcolor = p.yellow,
        row2label = "LINK",
        row2kind = "stats",
        row2stattype = "min",
        row2source = "link",
        row2transform = "floor",
        row2unit = "dB",
        row2textcolor = p.yellow
    }))

    add(out, titledValueBox(W, H, 0.80, 0.30, 0.11, 0.16, "text", "stats", "ESC MAX", opts.biglabelfont, opts.rightvaluefont, p.line, p.white, {
        stattype = "max",
        source = "temp_esc",
        transform = "floor",
        titlespacing = titleGap
    }))
    add(out, labelBox(W, H, 0.80, 0.57, 0.12, 0.06, "STATUS", opts.headingfont, p.yellow, "center", p.bg))
    add(out, widgetBox(W, H, 0.76, 0.65, 0.19, 0.07, "text", "armflags", {
        font = opts.statusfont,
        textcolor = p.line,
        valuealign = "center",
        bgcolor = p.bg,
        thresholds = {
            {value = "@i18n(widgets.governor.ARMED)@", textcolor = p.yellow},
            {value = "@i18n(widgets.governor.DISARMED)@", textcolor = p.line}
        }
    }))

    add(out, titledValueBox(W, H, 0.03, 0.82, 0.12, 0.12, "time", "total", "TOTAL", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        titlespacing = titleGap
    }))
    add(out, titledValueBox(W, H, 0.18, 0.82, 0.14, 0.12, "time", "count", "FLIGHTS", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        titlespacing = titleGap
    }))
    add(out, titledValueBox(W, H, 0.35, 0.82, 0.12, 0.12, "text", "stats", "USED", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        stattype = "max",
        source = "smartconsumption",
        transform = "floor",
        unit = "mAh",
        titlespacing = titleGap
    }))
    add(out, titledValueBox(W, H, 0.48, 0.82, 0.17, 0.12, "text", "stats", "MAX CURR", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        stattype = "max",
        source = "current",
        decimals = 1,
        unit = "A",
        titlespacing = titleGap
    }))
    add(out, titledValueBox(W, H, 0.66, 0.82, 0.12, 0.12, "text", "stats", "ESC MAX", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        stattype = "max",
        source = "temp_esc",
        transform = "floor",
        titlespacing = titleGap
    }))
    add(out, titledValueBox(W, H, 0.81, 0.82, 0.13, 0.12, "text", "stats", "CELL MIN", opts.bottomtitlefont, opts.bottomvaluefont, p.line, p.white, {
        stattype = "min",
        source = "voltage",
        unit = "V",
        transform = maxVoltageToCellVoltage,
        titlespacing = titleGap
    }))

    return out
end

return common
