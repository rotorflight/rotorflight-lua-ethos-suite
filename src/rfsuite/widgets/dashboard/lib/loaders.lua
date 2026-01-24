--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local loaders = {}

local function fmtRadioLinkType()


    local currentSensor
    local currentModuleId 
    local currentModuleNumber 
    local currentTelemetryType 
    local rf

    local internalModule = model.getModule(0)   
    local externalModule = model.getModule(1)

    if internalModule and internalModule:enable() then
        currentSensor = system.getSource({appId = 0xF101})
        currentModuleId = internalModule
        currentModuleNumber = 0
        currentTelemetryType = "sport"
    elseif externalModule and externalModule:enable() then
        currentSensor = system.getSource({crsfId = 0x14, subIdStart = 0, subIdEnd = 1})
        currentModuleId = externalModule
        currentTelemetryType = "crsf"
        currentModuleNumber = 1
        if not currentSensor then
            currentSensor = system.getSource({appId = 0xF101})
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
    local base = string.format("RFSUITE %d.%d.%d", major, minor, rev)
    if sfx and sfx ~= "" then
        base = base .. "-" .. tostring(sfx)
    end
    return base
end

local function fmtEthosVersion()
    if not system or type(system.getVersion) ~= "function" then return "Ethos ?" end
    local ok, info = pcall(system.getVersion)
    if not ok or type(info) ~= "table" then return "Ethos ?" end
    local board = info.board or "Ethos"
    -- Prefer the full version string if present
    local ver = info.version
    if not ver or ver == "" then
        local major = tonumber(info.major) or 0
        local minor = tonumber(info.minor) or 0
        local rev   = tonumber(info.revision) or 0
        ver = string.format("%d.%d.%d", major, minor, rev)
        if info.suffix and info.suffix ~= "" then ver = ver .. "-" .. tostring(info.suffix) end
    end
    return string.format("%s %s", tostring(board), tostring(ver))
end

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
    local isDark = lcd.darkMode()

    local outer = isDark
        and lcd.RGB(255, 255, 255, 1.0)
        or  lcd.GREY(64, 1.0)

    local inner = isDark
        and lcd.RGB(0,   0,   0,   1.0)
        or  lcd.RGB(128, 128, 128, 1.0)

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

    -- Right-side info column 
    local infoWRatio = opts.infoWRatio or 0.45   -- 0.30..0.42 feels good
    local infoW = math.max(1, math.floor(logoW * infoWRatio))

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
    local imageName = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/gfx/logo.png"
    local bmp = rfsuite.utils.loadImage(imageName)

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
        local okW, bw = pcall(function() return bmp:width() end)
        local okH, bh = pcall(function() return bmp:height() end)

        if okW and okH and type(bw) == "number" and type(bh) == "number" and bw > 0 and bh > 0 then
            local padX = math.floor(logoAreaW * (opts.logoPadXRatio or 0.06))
            local padY = math.floor(logoAreaH * (opts.logoPadYRatio or 0.18))
            local boxW = math.max(1, logoAreaW - 2 * padX)
            local boxH = math.max(1, logoAreaH - 2 * padY)

            local scale = math.min(boxW / bw, boxH / bh) * (opts.logoScale or 1.0)
            local drawW = math.max(1, math.floor(bw * scale))
            local drawH = math.max(1, math.floor(bh * scale))

            lcd.drawBitmap(
                math.floor(anchorX - drawW / 2),
                math.floor(anchorY - drawH / 2),
                bmp,
                drawW,
                drawH
            )
        else
            -- Fallback: square-fit method
            drawLogoImage(anchorX, anchorY, logoAreaW * (opts.logoFallbackWScale or 0.4), logoAreaH, opts.logoScale or 0.95)
        end
    end

    -- Right info column: separator + versions
    do
        local isDark = lcd.darkMode()
        local txt = isDark and lcd.RGB(255,255,255,1.0) or lcd.RGB(0,0,0,1.0)

        local padX = math.max(4, math.floor(infoW * 0.10))
        local padY = math.max(4, math.floor(infoH * 0.14))
        local iy = infoY + padY

        -- Vertical separator line (kept)
        local sepW = math.max(1, math.floor(infoW * 0.02))
        local sepCol = isDark and lcd.RGB(90,90,90,1.0) or lcd.RGB(110,110,110,1.0)
        lcd.color(sepCol)
        lcd.drawFilledRectangle(infoX + math.floor(sepW / 2), infoY + padY, sepW, math.max(1, infoH - 2 * padY))

        -- Text starts after the separator with a little gap
        local gap = math.max(6, math.floor(infoW * 0.03))
        local tx = infoX + padX + sepW + gap
        local tw = (infoX + infoW) - tx - padX

        local t1 = fmtRfsuiteVersion()
        local t2 = fmtEthosVersion()
        local t3 = fmtRadioLinkType() 

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
    lcd.color(isDark
        and lcd.RGB(255, 255, 255, 1.0)
        or  lcd.RGB(0,   0,   0,   1.0)
    )

    -- Prefer the smaller fonts so we get more lines in the console area.
    local fontSize = opts.fontSize or FONT_XXS
    lcd.font(fontSize)
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

-- A lightweight, mostly-static loader for screen transitions.
-- Keeps the same panel sizing + styling as logsLoader, but avoids rendering
-- the right-side version column and the console/log area.
function loaders.staticLoader(dashboard, x, y, w, h, message, opts)
    opts = opts or {}

    -- Panel size (mirrors logsLoader defaults)
    local panelW = math.floor(w * (opts.panelWidthRatio or 0.7))
    local panelH = math.floor(h * (opts.panelHeightRatio or 0.6))
    local panelX = math.floor(x + (w - panelW) / 2 + 0.5)
    local panelY = math.floor(y + (h - panelH) / 2 + 0.5)

    -- Prevent 1px clipping at the edges due to rounding
    panelX = math.max(x + 1, math.min(panelX, x + w - panelW - 1))
    panelY = math.max(y + 1, math.min(panelY, y + h - panelH - 1))

    local borderW = opts.borderW or math.max(4, math.floor(math.min(panelW, panelH) * 0.06))
    local cornerR = opts.cornerR or math.floor(math.min(panelW, panelH) * 0.14)

    local isDark = lcd.darkMode()
    local outer = isDark
        and lcd.RGB(255, 255, 255, 1.0)
        or  lcd.GREY(64, 1.0)
    local inner = isDark
        and lcd.RGB(0,   0,   0,   1.0)
        or  lcd.RGB(128, 128, 128, 1.0)

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
        drawFilledRoundRect(innerX, innerY, innerW, innerH, math.max(0, cornerR - borderW))
    end

    local pad = math.max(6, math.floor(panelH * 0.10))
    local contentX = innerX + pad
    local contentY = innerY + pad
    local contentW = innerW - 2 * pad
    local contentH = innerH - 2 * pad
    if contentW <= 1 or contentH <= 1 then return end

    -- Split: logo (top), message (bottom)
    local splitGap = math.max(6, math.floor(contentH * (opts.splitGapRatio or 0.06)))
    local logoH = math.floor(contentH * (opts.logoHeightRatio or 0.60))
    logoH = math.max(1, math.min(logoH, contentH - splitGap - 1))
    local msgH = contentH - logoH - splitGap

    local logoX = contentX
    local logoY = contentY
    local logoW = contentW

    local msgX = contentX
    local msgY = contentY + logoH + splitGap
    local msgW = contentW

    -- Draw logo (same asset as logsLoader)
    do
        local imageName = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/gfx/logo.png"
        local bmp = rfsuite.utils.loadImage(imageName)

        local cx = logoX + logoW * 0.5
        local cy = logoY + logoH * 0.5

        if bmp then
            local okW, bw = pcall(function() return bmp:width() end)
            local okH, bh = pcall(function() return bmp:height() end)
            if okW and okH and type(bw) == "number" and type(bh) == "number" and bw > 0 and bh > 0 then
                local padX = math.floor(logoW * (opts.logoPadXRatio or 0.10))
                local padY = math.floor(logoH * (opts.logoPadYRatio or 0.20))
                local boxW = math.max(1, logoW - 2 * padX)
                local boxH = math.max(1, logoH - 2 * padY)

                local scale = math.min(boxW / bw, boxH / bh) * (opts.logoScale or 1.0)
                local drawW = math.max(1, math.floor(bw * scale))
                local drawH = math.max(1, math.floor(bh * scale))

                lcd.drawBitmap(
                    math.floor(cx - drawW / 2),
                    math.floor(cy - drawH / 2),
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
        local fg = isDark and lcd.RGB(255, 255, 255, 1.0) or lcd.RGB(0, 0, 0, 1.0)
        lcd.color(fg)

        -- Provide a tiny bit of life without needing real log lines.
        -- (4-state dot animation, but still "static" enough.)
        local msg = message
        if (not msg or msg == "") and dashboard then
            msg = dashboard._overlay_text or dashboard.overlayMessage or "@i18n(app.msg_loading)@"
        end
        msg = tostring(msg or "@i18n(app.msg_loading)@")

        if opts.animateDots ~= false then
            local phase = math.floor((os.clock() * (opts.dotRate or 1.4)) % 4)
            msg = msg .. string.rep(".", phase)
        end

        local fonts = opts.fonts
        if not fonts and dashboard and dashboard.utils and type(dashboard.utils.getFontListsForResolution) == "function" then
            fonts = dashboard.utils.getFontListsForResolution().value_default
        end
        fonts = fonts or {FONT_XL, FONT_L, FONT_M, FONT_S, FONT_XS, FONT_XXS}

        local padY = math.max(2, math.floor(msgH * 0.10))
        local textH = math.max(1, msgH - 2 * padY)

        local lines, chosenFont, lineH = getWrappedTextLines(msg, fonts, msgW, textH)
        lcd.font(chosenFont)

        local totalH = #lines * lineH
        local baseY = msgY + math.floor((msgH - totalH) / 2)
        for i, line in ipairs(lines) do
            local tw = lcd.getTextSize(line)
            lcd.drawText(msgX + math.floor((msgW - tw) / 2), baseY + (i - 1) * lineH, line)
        end
    end
end

return loaders
