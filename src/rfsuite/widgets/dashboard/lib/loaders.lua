--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local lcd = lcd
local system = system
local model = model

local floor = math.floor
local min = math.min
local max = math.max
local format = string.format
local rep = string.rep
local insert = table.insert
local clock = os.clock
local ipairs = ipairs
local tostring = tostring
local tonumber = tonumber

local loaders = {}

local logoBitmapCachePath = nil
local logoBitmapCacheValue = nil
local DEFAULT_WRAP_FONTS = {FONT_XL, FONT_L, FONT_M, FONT_S, FONT_XS, FONT_XXS}
local FG_COLOR_DARK = lcd.RGB(255, 255, 255, 1.0)
local FG_COLOR_LIGHT = lcd.RGB(0, 0, 0, 1.0)
local PANEL_OUTER_DARK = lcd.RGB(255, 255, 255, 1.0)
local PANEL_OUTER_LIGHT = lcd.GREY(64, 1.0)
local PANEL_INNER_DARK = lcd.RGB(0, 0, 0, 1.0)
local PANEL_INNER_LIGHT = lcd.RGB(128, 128, 128, 1.0)
local PANEL_SEP_DARK = lcd.RGB(90, 90, 90, 1.0)
local PANEL_SEP_LIGHT = lcd.RGB(110, 110, 110, 1.0)
local WRAPPED_TEXT_LINES_BUFFER = {}
local LOG_LINES_BUFFER = {}
local EMPTY_OPTS = {}
local INFO_LINES_CACHE = {lastUpdate = 0, line1 = nil, line2 = nil, line3 = nil}
local INFO_LINES_UPDATE_INTERVAL = 0.5
local SOURCE_DESC_SPORT = {appId = 0xF101}
local SOURCE_DESC_CRSF = {crsfId = 0x14, subIdStart = 0, subIdEnd = 1}

local function clearArray(t)
    for i = #t, 1, -1 do t[i] = nil end
end

local function getLogoBitmap()
    local baseDir = (rfsuite and rfsuite.config and rfsuite.config.baseDir) or "rfsuite"
    local imageName = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/gfx/logo.png"

    if logoBitmapCachePath ~= imageName then
        logoBitmapCachePath = imageName
        logoBitmapCacheValue = rfsuite.utils.loadImage(imageName)
    elseif not logoBitmapCacheValue then
        logoBitmapCacheValue = rfsuite.utils.loadImage(imageName)
    end

    return logoBitmapCacheValue
end

local function fmtRadioLinkType()


    local currentSensor
    local currentModuleId 
    local currentModuleNumber 
    local currentTelemetryType 
    local rf

    local internalModule = model.getModule(0)   
    local externalModule = model.getModule(1)

    if internalModule and internalModule:enable() then
        currentSensor = system.getSource(SOURCE_DESC_SPORT)
        currentModuleId = internalModule
        currentModuleNumber = 0
        currentTelemetryType = "sport"
    elseif externalModule and externalModule:enable() then
        currentSensor = system.getSource(SOURCE_DESC_CRSF)
        currentModuleId = externalModule
        currentTelemetryType = "crsf"
        currentModuleNumber = 1
        if not currentSensor then
            currentSensor = system.getSource(SOURCE_DESC_SPORT)
            currentTelemetryType = "sport"
        end
    else    
        currentSensor = nil
        currentModuleId = nil
        currentModuleNumber = -1
        currentTelemetryType = "none"
    end


    -- Determine RF link type string
    
    if currentModuleNumber == -1 then
        return "RF Module Disabled"
    elseif currentModuleNumber == 0 and currentSensor == nil then 
         rf = "Int. No Telemetry"  
    elseif currentModuleNumber == 1 and currentSensor == nil then 
         rf = "Ext. No Telemetry"     
    elseif currentModuleNumber == 0 and currentTelemetryType == "sport" then
         rf = "Int. FBUS/F.PORT/S.PORT"
    elseif currentModuleNumber == 1 and currentTelemetryType == "sport" then
         rf = "Ext. FBUS/F.PORT/S.PORT"  
    elseif currentModuleNumber == 1 and currentTelemetryType == "crsf" then 
         rf = "Ext. CRSF"    
    else
         rf = "Unknown RF Link"      
    end

    return rf

end

local function fmtRfsuiteVersion()
    local v = rfsuite and rfsuite.config and rfsuite.config.version
    if type(v) ~= "table" then return "rfsuite ?" end
    local major = tonumber(v.major) or 0
    local minor = tonumber(v.minor) or 0
    local rev   = tonumber(v.revision) or 0
    local sfx   = v.suffix
    local base = format("RFSUITE %d.%d.%d", major, minor, rev)
    if sfx and sfx ~= "" then
        base = base .. "-" .. tostring(sfx)
    end
    return base
end

local function fmtEthosVersion()
    if not system or type(system.getVersion) ~= "function" then
        return "Ethos ?"
    end

    local info = system.getVersion()
    if type(info) ~= "table" then
        return "Ethos ?"
    end

    local board = info.board or "Ethos"

    -- Prefer the full version string if present
    local ver = info.version
    if not ver or ver == "" then
        local major = tonumber(info.major) or 0
        local minor = tonumber(info.minor) or 0
        local rev   = tonumber(info.revision) or 0

        ver = format("%d.%d.%d", major, minor, rev)

        if info.suffix and info.suffix ~= "" then
            ver = ver .. "-" .. tostring(info.suffix)
        end
    end

    return format("%s %s", tostring(board), tostring(ver))
end

local function getInfoLinesCached()
    local now = clock()
    local cache = INFO_LINES_CACHE
    if (cache.line1 == nil) or ((now - (cache.lastUpdate or 0)) >= INFO_LINES_UPDATE_INTERVAL) then
        cache.lastUpdate = now
        cache.line1 = fmtRfsuiteVersion()
        cache.line2 = fmtEthosVersion()
        cache.line3 = fmtRadioLinkType()
    end
    return cache.line1, cache.line2, cache.line3
end


-- Draw a filled rounded rectangle using primitives (no alpha blending).
-- r is corner radius in pixels.
local function drawFilledRoundRect(x, y, w, h, r)
    -- Round inputs once (avoid float leakage)
    x = floor((x or 0) + 0.5)
    y = floor((y or 0) + 0.5)
    w = floor((w or 0) + 0.5)
    h = floor((h or 0) + 0.5)

    if w <= 0 or h <= 0 then return end

    r = floor((r or 0) + 0.5)
    r = max(0, min(r, floor(min(w, h) / 2)))

    if r <= 0 or not lcd.drawFilledCircle then
        lcd.drawFilledRectangle(x, y, w, h)
        return
    end

    -- Inclusive bounds (last pixel)
    local x2 = x + w - 1
    local y2 = y + h - 1

    -- Rectangles (pixel-count widths)
    lcd.drawFilledRectangle(x + r, y, w - 2 * r, h)            -- center
    lcd.drawFilledRectangle(x, y + r, r, h - 2 * r)            -- left
    lcd.drawFilledRectangle(x2 - r + 1, y + r, r, h - 2 * r)   -- right

    -- Corner circle centers (align to inclusive bounds)
    local cxL = x + r 
    local cxR = x2 - r
    local cyT = y + r 
    local cyB = y2 - r

    lcd.drawFilledCircle(cxL, cyT + 0.05, r)
    lcd.drawFilledCircle(cxR, cyT + 0.05, r)
    lcd.drawFilledCircle(cxL, cyB + 0.05, r)
    lcd.drawFilledCircle(cxR, cyB + 0.05, r)
end

local function drawRoundRectFrame(x, y, w, h, r, borderW)
    x = floor((x or 0) + 0.5)
    y = floor((y or 0) + 0.5)
    w = floor((w or 0) + 0.5)
    h = floor((h or 0) + 0.5)
    if w <= 0 or h <= 0 then return end

    borderW = max(1, floor((borderW or 2) + 0.5))
    r = floor((r or 0) + 0.5)

    drawFilledRoundRect(x, y, w, h, r)

    local iw = w - 2 * borderW
    local ih = h - 2 * borderW
    if iw > 0 and ih > 0 then
        drawFilledRoundRect(
            x + borderW,
            y + borderW,
            iw,
            ih,
            max(0, r - borderW)
        )
    end
end



local function drawLogoImage(cx, cy, w, h, scale)
    local bmp = getLogoBitmap()
    if bmp then
        -- scale is a ratio of the provided box size (min(w,h)).
        -- Default to 40% which works well for the rectangular loader panel.
        scale = scale or 0.40
        local imgSize = min(w, h) * scale
        lcd.drawBitmap(cx - imgSize / 2, cy - imgSize / 2, bmp, imgSize, imgSize)
    end
end

local function ellipsizeRight(s, maxW)
    if not s or s == "" then return "" end
    if lcd.getTextSize(s) <= maxW then return s end
    local t = s
    while #t > 1 and lcd.getTextSize(t .. "…") > maxW do
        t = t:sub(1, -2)
    end
    return t .. "…"
end

local function resolveLogLines(linesSrc, maxLines, out)
    maxLines = maxLines or 4
    local lines = out or {}
    clearArray(lines)
    if not linesSrc then return lines end

    -- Function source
    if type(linesSrc) == "function" then
        local res = linesSrc(maxLines)
        if type(res) == "table" then return res end
        return lines
    end

    -- Table source
    if type(linesSrc) == "table" then
        -- Object style: getLines(max)
        if type(linesSrc.getLines) == "function" then
            local res = linesSrc:getLines(maxLines)
            if type(res) == "table" then return res end
        end

        -- Plain array of lines
        if #linesSrc > 0 then
            local start = max(1, #linesSrc - maxLines + 1)
            for i = start, #linesSrc do lines[#lines + 1] = tostring(linesSrc[i]) end
        end
    end

    return lines
end


local function getWrappedTextLines(message, fonts, maxWidth, maxHeight, outLines)
    local lines = outLines or {}
    clearArray(lines)
    fonts = fonts or DEFAULT_WRAP_FONTS
    local chosenFont = fonts[1]
    local _, lineH = lcd.getTextSize("Ay")

    for i = #fonts, 1, -1 do
        lcd.font(fonts[i])
        local tw, th = lcd.getTextSize(message)
        if tw <= maxWidth and th <= maxHeight then
            chosenFont = fonts[i]
            _, lineH = lcd.getTextSize("Ay")
            break
        end
    end

    local current = nil
    for w in tostring(message or ""):gmatch("%S+") do
        if not current then
            current = w
        else
            local test = current .. " " .. w
            if lcd.getTextSize(test) <= maxWidth then
                current = test
            else
                insert(lines, current)
                current = w
            end
        end
    end
    if current then
        insert(lines, current)
    else
        insert(lines, "")
    end
    local maxLines = max(1, floor(maxHeight / lineH))
    if #lines > maxLines then
        for i = #lines, maxLines + 1, -1 do
            lines[i] = nil
        end
        local last = lines[maxLines] or ""
        while lcd.getTextSize(last .. "…") > maxWidth and #last > 1 do last = last:sub(1, -2) end
        lines[maxLines] = last .. "…"
    end

    return lines, chosenFont, lineH
end

local function drawOverlayBackground(cx, cy, innerR, bg)
    lcd.color(bg)
    if lcd.drawFilledCircle then
        lcd.drawFilledCircle(cx, cy, innerR)
    else
        lcd.drawFilledRectangle(cx - innerR, cy - innerR, innerR * 2, innerR * 2)
    end
end

local function renderOverlayText(dashboard, cx, cy, innerR, fg)
    local message = dashboard._overlay_text or "@i18n(widgets.dashboard.loading)@"
    local fonts = dashboard.utils.getFontListsForResolution().value_default
    local lines, chosenFont, lineH = getWrappedTextLines(message, fonts, innerR * 2 * 0.9, innerR * 2 * 0.8, WRAPPED_TEXT_LINES_BUFFER)

    lcd.color(fg)
    lcd.font(chosenFont)
    local totalH = #lines * lineH
    for i, line in ipairs(lines) do
        local tw = lcd.getTextSize(line)
        lcd.drawText(cx - tw / 2, cy - totalH / 2 + (i - 1) * lineH, line)
    end
end

function loaders.logsLoader(dashboard, x, y, w, h, linesSrc, opts)
    opts = opts or EMPTY_OPTS

    -- Panel size (roughly "50% screen area" by default)
    local panelW = floor(w * (opts.panelWidthRatio or 0.7))
    local panelH = floor(h * (opts.panelHeightRatio or 0.6))
    local panelX = floor(x + (w - panelW) / 2 + 0.5)
    local panelY = floor(y + (h - panelH) / 2 + 0.5)

    -- Prevent 1px clipping at the edges due to rounding
    panelX = max(x + 1, min(panelX, x + w - panelW - 1))
    panelY = max(y + 1, min(panelY, y + h - panelH - 1))

    local borderW = opts.borderW or max(4, floor(min(panelW, panelH) * 0.06))
    local cornerR = opts.cornerR or floor(min(panelW, panelH) * 0.14)

    -- Frame like the circle: bright outer, dark inner.
    local isDark = lcd.darkMode()

    local outer = isDark and PANEL_OUTER_DARK or PANEL_OUTER_LIGHT

    local inner = isDark and PANEL_INNER_DARK or PANEL_INNER_LIGHT

    -- Outer frame
    lcd.color(outer)
    drawFilledRoundRect(panelX, panelY, panelW, panelH, cornerR)

    -- Inner fill (force integer sizes to avoid 1px bottom "misalignment")
    local innerX = panelX + borderW
    local innerY = panelY + borderW
    local innerW = panelW - 2 * borderW
    local innerH = panelH - 2 * borderW
    if innerW > 0 and innerH > 0 then
        lcd.color(inner)
        drawFilledRoundRect(innerX, innerY, innerW, innerH, max(0, cornerR - borderW))
    end

    local pad = max(6, floor(panelH * 0.10))
    local contentX = innerX + pad
    local contentY = innerY + pad
    local contentW = innerW - 2 * pad
    local contentH = innerH - 2 * pad
    if contentW <= 1 or contentH <= 1 then return end

    -- Split: logo (top), console (bottom)
    local splitGap = max(6, floor(contentH * (opts.splitGapRatio or 0.06)))
    local logoH = floor(contentH * (opts.logoHeightRatio or 0.50))
    logoH = max(1, min(logoH, contentH - splitGap - 1))
    local logH = contentH - logoH - splitGap

    local logoX = contentX
    local logoY = contentY
    local logoW = contentW

    -- Right-side info column 
    local infoWRatio = opts.infoWRatio or 0.45   -- 0.30..0.42 feels good
    local infoW = max(1, floor(logoW * infoWRatio))

    local logX = contentX
    local logY = contentY + logoH + splitGap
    local logW = contentW

    -- Split top area into: [logo area | info area]
    local infoX = logoX + (logoW - infoW)
    local infoY = logoY
    local infoH = logoH

    local logoAreaX = logoX
    local logoAreaY = logoY
    local logoAreaW = logoW - infoW
    local logoAreaH = logoH

     -- Draw logo in the top half
    local bmp = getLogoBitmap()

    -- Alignment: "center" (default) or "left"
    local align = "left" 

    -- Where in the logo area to anchor the logo centre point
    local anchorX
    if align == "left" then
        anchorX = logoAreaX + logoAreaW * (opts.logoAnchorX or 0.30)  -- tweak 0.20..0.40
    else
        anchorX = logoAreaX + logoAreaW * 0.50
    end
    local anchorY = logoAreaY + logoAreaH * 0.50

    if bmp then
        local bw = bmp:width()
        local bh = bmp:height()

        if type(bw) == "number" and type(bh) == "number" and bw > 0 and bh > 0 then
            local padX = floor(logoAreaW * (opts.logoPadXRatio or 0.06))
            local padY = floor(logoAreaH * (opts.logoPadYRatio or 0.18))
            local boxW = max(1, logoAreaW - 2 * padX)
            local boxH = max(1, logoAreaH - 2 * padY)

            local scale = min(boxW / bw, boxH / bh) * (opts.logoScale or 1.0)
            local drawW = max(1, floor(bw * scale))
            local drawH = max(1, floor(bh * scale))

            lcd.drawBitmap(
                floor(anchorX - drawW / 2),
                floor(anchorY - drawH / 2),
                bmp,
                drawW,
                drawH
            )
        else
            -- Fallback: square-fit method
            drawLogoImage(
                anchorX,
                anchorY,
                logoAreaW * (opts.logoFallbackWScale or 0.4),
                logoAreaH,
                opts.logoScale or 0.95
            )
        end
    end


    -- Right info column: separator + versions
    do
        local txt = isDark and FG_COLOR_DARK or FG_COLOR_LIGHT

        local padX = max(4, floor(infoW * 0.10))
        local padY = max(4, floor(infoH * 0.14))
        local iy = infoY + padY

        -- Vertical separator line (kept)
        local sepW = max(1, floor(infoW * 0.02))
        local sepCol = isDark and PANEL_SEP_DARK or PANEL_SEP_LIGHT
        lcd.color(sepCol)
        lcd.drawFilledRectangle(infoX + floor(sepW / 2), infoY + padY, sepW, max(1, infoH - 2 * padY))

        -- Text starts after the separator with a little gap
        local gap = max(6, floor(infoW * 0.03))
        local tx = infoX + padX + sepW + gap
        local tw = (infoX + infoW) - tx - padX

        local t1, t2, t3 = getInfoLinesCached()

        lcd.color(txt)
        local fontSize = opts.fontSize or FONT_XXS
        lcd.font(fontSize)

        local _, th = lcd.getTextSize("Ay")

        -- line 1: rfsuite version
        lcd.drawText(tx, iy,          ellipsizeRight(t1, tw))

        -- line 2: ethos version
        lcd.drawText(tx, iy + th,     ellipsizeRight(t2, tw))

        -- line 3: radio/link type
        lcd.drawText(tx, iy + th * 2, ellipsizeRight(t3, tw))

    end


    -- Bottom side: log lines
    lcd.color(isDark and FG_COLOR_DARK or FG_COLOR_LIGHT)

    -- Prefer the smaller fonts so we get more lines in the console area.
    local fontSize = opts.fontSize or FONT_XXS
    lcd.font(fontSize)
    local _, lineH = lcd.getTextSize("Ay")
    lineH = max(1, lineH)

    local maxLines = max(1, floor((logH) / lineH))
    local lines = resolveLogLines(linesSrc, maxLines, LOG_LINES_BUFFER)

    -- If caller didn't pass a source, try common dashboard fields.
    if (not lines or #lines == 0) and dashboard then
        lines = resolveLogLines(dashboard._log_lines or dashboard.logLines or dashboard.logQueue or dashboard.startupQueue, maxLines, LOG_LINES_BUFFER)
    end

    -- Draw bottom-aligned (console), with safe padding.
    local safeTop = logY
    local safeBottom = logY + logH - 1
    local n = min(#lines, maxLines)
    local lastLineY = safeBottom - lineH
    for i = 1, n do
        local s = tostring(lines[#lines - n + i])
        s = ellipsizeRight(s, logW)
        local yy = floor(lastLineY - (n - i) * lineH)
        if yy >= safeTop and (yy + lineH) <= (safeBottom + 1) then
            lcd.drawText(logX, yy, s)
        end
    end
end

-- A lightweight, mostly-static loader for screen transitions.
-- Keeps the same panel sizing + styling as logsLoader, but avoids rendering
-- the right-side version column and the console/log area.
function loaders.staticLoader(dashboard, x, y, w, h, message, opts)
    opts = opts or EMPTY_OPTS

    -- Panel size (mirrors logsLoader defaults)
    local panelW = floor(w * (opts.panelWidthRatio or 0.7))
    local panelH = floor(h * (opts.panelHeightRatio or 0.6))
    local panelX = floor(x + (w - panelW) / 2 + 0.5)
    local panelY = floor(y + (h - panelH) / 2 + 0.5)

    -- Prevent 1px clipping at the edges due to rounding
    panelX = max(x + 1, min(panelX, x + w - panelW - 1))
    panelY = max(y + 1, min(panelY, y + h - panelH - 1))

    local borderW = opts.borderW or max(4, floor(min(panelW, panelH) * 0.06))
    local cornerR = opts.cornerR or floor(min(panelW, panelH) * 0.14)

    local isDark = lcd.darkMode()
    local outer = isDark and PANEL_OUTER_DARK or PANEL_OUTER_LIGHT
    local inner = isDark and PANEL_INNER_DARK or PANEL_INNER_LIGHT

    -- Outer frame
    lcd.color(outer)
    drawFilledRoundRect(panelX, panelY, panelW, panelH, cornerR)

    -- Inner fill
    local innerX = panelX + borderW
    local innerY = panelY + borderW
    local innerW = panelW - 2 * borderW
    local innerH = panelH - 2 * borderW
    if innerW > 0 and innerH > 0 then
        lcd.color(inner)
        drawFilledRoundRect(innerX, innerY, innerW, innerH, max(0, cornerR - borderW))
    end

    local pad = max(6, floor(panelH * 0.10))
    local contentX = innerX + pad
    local contentY = innerY + pad
    local contentW = innerW - 2 * pad
    local contentH = innerH - 2 * pad
    if contentW <= 1 or contentH <= 1 then return end

    -- Split: logo (top), message (bottom)
    local splitGap = max(6, floor(contentH * (opts.splitGapRatio or 0.06)))
    local logoH = floor(contentH * (opts.logoHeightRatio or 0.60))
    logoH = max(1, min(logoH, contentH - splitGap - 1))
    local msgH = contentH - logoH - splitGap

    local logoX = contentX
    local logoY = contentY
    local logoW = contentW

    local msgX = contentX
    local msgY = contentY + logoH + splitGap
    local msgW = contentW

    -- Draw logo (same asset as logsLoader)
    do
        local bmp = getLogoBitmap()

        local cx = logoX + logoW * 0.5
        local cy = logoY + logoH * 0.5

        if bmp then
            local bw = bmp:width()
            local bh = bmp:height()

            if type(bw) == "number" and type(bh) == "number" and bw > 0 and bh > 0 then
                local padX = floor(logoW * (opts.logoPadXRatio or 0.10))
                local padY = floor(logoH * (opts.logoPadYRatio or 0.20))
                local boxW = max(1, logoW - 2 * padX)
                local boxH = max(1, logoH - 2 * padY)

                local scale = min(boxW / bw, boxH / bh) * (opts.logoScale or 1.0)
                local drawW = max(1, floor(bw * scale))
                local drawH = max(1, floor(bh * scale))

                lcd.drawBitmap(
                    floor(cx - drawW / 2),
                    floor(cy - drawH / 2),
                    bmp,
                    drawW,
                    drawH
                )
            else
                drawLogoImage(cx, cy, logoW, logoH, opts.logoFallbackWScale or 0.40)
            end
        else
            drawLogoImage(cx, cy, logoW, logoH, opts.logoFallbackWScale or 0.40)
        end
    end


    -- Message area
    do
        local fg = isDark and FG_COLOR_DARK or FG_COLOR_LIGHT
        lcd.color(fg)

        -- Provide a tiny bit of life without needing real log lines.
        -- (4-state dot animation, but still "static" enough.)
        local msg = message
        if (not msg or msg == "") and dashboard then
            msg = dashboard._overlay_text or dashboard.overlayMessage or "@i18n(app.msg_loading)@"
        end
        msg = tostring(msg or "@i18n(app.msg_loading)@")

        if opts.animateDots ~= false then
            local phase = floor((clock() * (opts.dotRate or 1.4)) % 4)
            msg = msg .. rep(".", phase)
        end

        local fonts = opts.fonts
        if not fonts and dashboard and dashboard.utils and type(dashboard.utils.getFontListsForResolution) == "function" then
            fonts = dashboard.utils.getFontListsForResolution().value_default
        end
        fonts = fonts or DEFAULT_WRAP_FONTS

        local padY = max(2, floor(msgH * 0.10))
        local textH = max(1, msgH - 2 * padY)

        local lines, chosenFont, lineH = getWrappedTextLines(msg, fonts, msgW, textH, WRAPPED_TEXT_LINES_BUFFER)
        lcd.font(chosenFont)

        local totalH = #lines * lineH
        local baseY = msgY + floor((msgH - totalH) / 2)
        for i, line in ipairs(lines) do
            local tw = lcd.getTextSize(line)
            lcd.drawText(msgX + floor((msgW - tw) / 2), baseY + (i - 1) * lineH, line)
        end
    end
end

return loaders
