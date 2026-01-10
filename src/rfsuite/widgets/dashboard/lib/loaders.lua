--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local loaders = {}

-- Draw a filled rounded rectangle using primitives (no alpha blending).
-- r is corner radius in pixels.
local function drawFilledRoundRect(x, y, w, h, r)
    -- Round inputs once (avoid float leakage)
    x = math.floor((x or 0) + 0.5)
    y = math.floor((y or 0) + 0.5)
    w = math.floor((w or 0) + 0.5)
    h = math.floor((h or 0) + 0.5)

    if w <= 0 or h <= 0 then return end

    r = math.floor((r or 0) + 0.5)
    r = math.max(0, math.min(r, math.floor(math.min(w, h) / 2)))

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
    x = math.floor((x or 0) + 0.5)
    y = math.floor((y or 0) + 0.5)
    w = math.floor((w or 0) + 0.5)
    h = math.floor((h or 0) + 0.5)
    if w <= 0 or h <= 0 then return end

    borderW = math.max(1, math.floor((borderW or 2) + 0.5))
    r = math.floor((r or 0) + 0.5)

    drawFilledRoundRect(x, y, w, h, r)

    local iw = w - 2 * borderW
    local ih = h - 2 * borderW
    if iw > 0 and ih > 0 then
        drawFilledRoundRect(
            x + borderW,
            y + borderW,
            iw,
            ih,
            math.max(0, r - borderW)
        )
    end
end



local function drawLogoImage(cx, cy, w, h, scale)
    local imageName = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/gfx/logo.png"
    local bmp = rfsuite.utils.loadImage(imageName)
    if bmp then
        -- scale is a ratio of the provided box size (min(w,h)).
        -- Default to 40% which works well for the rectangular loader panel.
        scale = scale or 0.40
        local imgSize = math.min(w, h) * scale
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

local function resolveLogLines(linesSrc, maxLines)
    maxLines = maxLines or 4
    if not linesSrc then return {} end

    -- Function source
    if type(linesSrc) == "function" then
        local ok, res = pcall(linesSrc, maxLines)
        if ok and type(res) == "table" then return res end
        return {}
    end

    -- Table source
    if type(linesSrc) == "table" then
        -- Object style: getLines(max)
        if type(linesSrc.getLines) == "function" then
            local ok, res = pcall(linesSrc.getLines, linesSrc, maxLines)
            if ok and type(res) == "table" then return res end
        end
        -- Plain array of lines
        if #linesSrc > 0 then
            local out = {}
            local start = math.max(1, #linesSrc - maxLines + 1)
            for i = start, #linesSrc do out[#out + 1] = tostring(linesSrc[i]) end
            return out
        end
    end
    return {}
end

local function getWrappedTextLines(message, fonts, maxWidth, maxHeight)
    local lines = {}
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

    local function wrap(str)
        local words = {}
        for w in str:gmatch("%S+") do table.insert(words, w) end
        local current = words[1] or ""
        for i = 2, #words do
            local test = current .. " " .. words[i]
            if lcd.getTextSize(test) <= maxWidth then
                current = test
            else
                table.insert(lines, current)
                current = words[i]
            end
        end
        table.insert(lines, current)
    end

    wrap(message)
    local maxLines = math.floor(maxHeight / lineH)
    if #lines > maxLines then
        lines = {table.unpack(lines, 1, maxLines)}
        local last = lines[#lines]
        while lcd.getTextSize(last .. "…") > maxWidth and #last > 1 do last = last:sub(1, -2) end
        lines[#lines] = last .. "…"
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
    local lines, chosenFont, lineH = getWrappedTextLines(message, fonts, innerR * 2 * 0.9, innerR * 2 * 0.8)

    lcd.color(fg)
    lcd.font(chosenFont)
    local totalH = #lines * lineH
    for i, line in ipairs(lines) do
        local tw = lcd.getTextSize(line)
        lcd.drawText(cx - tw / 2, cy - totalH / 2 + (i - 1) * lineH, line)
    end
end

function loaders.staticLoader(dashboard, x, y, w, h)

    local cx, cy = x + w / 2, y + h / 2
    local radius = math.min(w, h) * (dashboard.loaderScale or 0.3)
    local thickness = math.max(6, radius * 0.15)

    local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0
    lcd.color(lcd.RGB(r, g, b, 1.0))

    if lcd.drawFilledCircle then
        lcd.drawFilledCircle(cx, cy, radius)
        lcd.color(lcd.darkMode() and lcd.RGB(0, 0, 0, 1.0) or lcd.RGB(0, 0, 0, 1.0))
        lcd.drawFilledCircle(cx, cy, radius - thickness)
    end

    drawLogoImage(cx, cy, w, h, 0.50)

    dashboard._dots_index = dashboard._dots_index or 1
    dashboard._dots_time = dashboard._dots_time or os.clock()
    if os.clock() - dashboard._dots_time > 0.5 then
        dashboard._dots_time = os.clock()
        dashboard._dots_index = (dashboard._dots_index % 3) + 1
    end

    local dotRadius = 4
    local spacing = 3 * dotRadius
    local startX = cx - spacing
    local yPos = cy + (radius - thickness / 2) / 2

    for i = 1, 3 do
        if i == dashboard._dots_index then
            lcd.color(lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(0, 0, 0))
        else
            lcd.color(lcd.darkMode() and lcd.RGB(80, 80, 80) or lcd.RGB(180, 180, 180))
        end
        lcd.drawFilledCircle(startX + (i - 1) * spacing, yPos, dotRadius)
    end

end

function loaders.staticOverlayMessage(dashboard, x, y, w, h, txt)
    dashboard._overlay_cycles_required = dashboard._overlay_cycles_required or math.ceil(5 / (dashboard.paint_interval or 0.5))
    dashboard._overlay_cycles = dashboard._overlay_cycles or 0

    if txt and txt ~= "" then
        dashboard._overlay_text = txt
        dashboard._overlay_cycles = dashboard._overlay_cycles_required
    end

    if dashboard._overlay_cycles <= 0 then return end
    dashboard._overlay_cycles = dashboard._overlay_cycles - 1

    local fg = lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(255, 255, 255)
    local bg = lcd.darkMode() and lcd.RGB(0, 0, 0, 1.0) or lcd.RGB(255, 255, 255, 1.0)

    local cx, cy = x + w / 2, y + h / 2
    local radius = math.min(w, h) * (dashboard.overlayScale or 0.35)
    local thickness = math.max(6, radius * 0.15)
    local innerR = radius - (thickness / 2) - 1

    drawOverlayBackground(cx, cy, innerR, bg)

    local r, g, b = lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0, lcd.darkMode() and 255 or 0
    lcd.color(lcd.RGB(r, g, b, 1.0))
    if lcd.drawFilledCircle then
        lcd.drawFilledCircle(cx, cy, radius)
        lcd.color(lcd.darkMode() and lcd.RGB(0, 0, 0, 1.0) or lcd.RGB(0, 0, 0, 1.0))
        lcd.drawFilledCircle(cx, cy, radius - thickness)
    end

    -- Keep Rotorflight logo visible inside the ring
    drawLogoImage(cx, cy, radius * 2, radius * 2, 0.50)

    dashboard._dots_index = dashboard._dots_index or 1
    dashboard._dots_time = dashboard._dots_time or os.clock()
    if os.clock() - dashboard._dots_time > 0.5 then
        dashboard._dots_time = os.clock()
        dashboard._dots_index = (dashboard._dots_index % 3) + 1
    end

    local dotRadius = 4
    local spacing = 3 * dotRadius
    local startX = cx - spacing
    local yPos = cy + (radius - thickness / 2) / 2

    for i = 1, 3 do
        if i == dashboard._dots_index then
            lcd.color(lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(0, 0, 0))
        else
            lcd.color(lcd.darkMode() and lcd.RGB(80, 80, 80) or lcd.RGB(180, 180, 180))
        end
        lcd.drawFilledCircle(startX + (i - 1) * spacing, yPos, dotRadius)
    end

    renderOverlayText(dashboard, cx, cy, innerR, fg)
end

-- A clean "traditional" loader panel:
-- big rounded box, bold frame, logo on the left, console log on the right, and 3 dots.
--
-- Usage:
--   loaders.logsLoader(dashboard, x, y, w, h, linesSrc[, opts])
-- Where linesSrc can be:
--   * function(maxLines)->{...}
--   * table array of strings
--   * object with :getLines(maxLines)
function loaders.logsLoader(dashboard, x, y, w, h, linesSrc, opts)
    opts = opts or {}

    -- Panel size (roughly "50% screen area" by default)
    local panelW = math.floor(w * (opts.panelWidthRatio or 0.7))
    local panelH = math.floor(h * (opts.panelHeightRatio or 0.6))
    local panelX = math.floor(x + (w - panelW) / 2 + 0.5)
    local panelY = math.floor(y + (h - panelH) / 2 + 0.5)

    -- Prevent 1px clipping at the edges due to rounding
    panelX = math.max(x + 1, math.min(panelX, x + w - panelW - 1))
    panelY = math.max(y + 1, math.min(panelY, y + h - panelH - 1))

    local borderW = opts.borderW or math.max(4, math.floor(math.min(panelW, panelH) * 0.06))
    local cornerR = opts.cornerR or math.floor(math.min(panelW, panelH) * 0.14)

    -- Frame like the circle: bright outer, dark inner.
    local outer = lcd.darkMode() and lcd.RGB(255, 255, 255, 1.0) or lcd.RGB(0, 0, 0, 1.0)
    local inner = lcd.RGB(0, 0, 0, 1.0)

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
        drawFilledRoundRect(innerX, innerY, innerW, innerH, math.max(0, cornerR - borderW))
    end

    local pad = math.max(6, math.floor(panelH * 0.10))
    local contentX = innerX + pad
    local contentY = innerY + pad
    local contentW = innerW - 2 * pad
    local contentH = innerH - 2 * pad
    if contentW <= 1 or contentH <= 1 then return end

    -- Split: logo (top), console (bottom)
    local splitGap = math.max(6, math.floor(contentH * (opts.splitGapRatio or 0.06)))
    local logoH = math.floor(contentH * (opts.logoHeightRatio or 0.50))
    logoH = math.max(1, math.min(logoH, contentH - splitGap - 1))
    local logH = contentH - logoH - splitGap

    local logoX = contentX
    local logoY = contentY
    local logoW = contentW

    local logX = contentX
    local logY = contentY + logoH + splitGap
    local logW = contentW

    -- Draw logo centered in the top half.
    -- For landscape logos, a top/bottom split gives better use of width.
    local logoCx = logoX + logoW / 2
    local logoCy = logoY + logoH / 2

    -- Try to preserve aspect ratio if the bitmap exposes size; otherwise fall back.
    local imageName = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/gfx/logo.png"
    local bmp = rfsuite.utils.loadImage(imageName)
    if bmp then
        local okW, bw = pcall(function() return bmp:width() end)
        local okH, bh = pcall(function() return bmp:height() end)
        if okW and okH and type(bw) == "number" and type(bh) == "number" and bw > 0 and bh > 0 then
            local padX = math.floor(logoW * (opts.logoPadXRatio or 0.06))
            local padY = math.floor(logoH * (opts.logoPadYRatio or 0.18))
            local boxW = math.max(1, logoW - 2 * padX)
            local boxH = math.max(1, logoH - 2 * padY)

            local scale = math.min(boxW / bw, boxH / bh) * (opts.logoScale or 1.0)
            local drawW = math.max(1, math.floor(bw * scale))
            local drawH = math.max(1, math.floor(bh * scale))

            lcd.drawBitmap(math.floor(logoCx - drawW / 2), math.floor(logoCy - drawH / 2), bmp, drawW, drawH)
        else
            -- Fallback: square-fit method (still fine for most logos)
            drawLogoImage(logoCx, logoCy, logoW, logoH, opts.logoScale or 0.95)
        end
    end

    -- Bottom side: log lines
    local fonts = dashboard.utils and dashboard.utils.getFontListsForResolution and dashboard.utils.getFontListsForResolution()
    fonts = (fonts and fonts.value_default) or {FONT_S, FONT_XS, FONT_XXS}
    lcd.color(lcd.RGB(255, 255, 255, 1.0))

    -- Prefer the smaller fonts so we get more lines in the console area.
    local chosenFont = fonts[#fonts] or FONT_XS
    lcd.font(FONT_XS)
    local _, lineH = lcd.getTextSize("Ay")
    lineH = math.max(1, lineH)

    local maxLines = math.max(1, math.floor((logH) / lineH))
    local lines = resolveLogLines(linesSrc, maxLines)

    -- If caller didn't pass a source, try common dashboard fields.
    if (not lines or #lines == 0) and dashboard then
        lines = resolveLogLines(dashboard._log_lines or dashboard.logLines or dashboard.logQueue or dashboard.startupQueue, maxLines)
    end

    -- Draw bottom-aligned (console), with safe padding.
    local safeTop = logY
    local safeBottom = logY + logH - 1
    local n = math.min(#lines, maxLines)
    local lastLineY = safeBottom - lineH
    for i = 1, n do
        local s = tostring(lines[#lines - n + i])
        s = ellipsizeRight(s, logW)
        local yy = math.floor(lastLineY - (n - i) * lineH)
        if yy >= safeTop and (yy + lineH) <= (safeBottom + 1) then
            lcd.drawText(logX, yy, s)
        end
    end
end

return loaders
