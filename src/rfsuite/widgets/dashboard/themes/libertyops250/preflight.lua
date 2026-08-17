local rfsuite = require("rfsuite")
local lcd = lcd
local system = system
local math = math
local floor = math.floor
local min = math.min
local max = math.max
local tonumber = tonumber
local tostring = tostring
local type = type
local format = string.format

local utils = rfsuite.widgets.dashboard.utils
local headeropts = utils.getHeaderOptions()
local header_layout = utils.standardHeaderLayout(headeropts)
local header_boxes_cache
local last_txbatt_type

local C = {
    bg = lcd.RGB(2, 5, 10),
    panel = lcd.RGB(5, 10, 18),
    panel2 = lcd.RGB(8, 16, 28),
    line = lcd.RGB(24, 76, 146),
    lineDim = lcd.RGB(15, 40, 72),
    white = lcd.RGB(238, 243, 252),
    muted = lcd.RGB(138, 153, 175),
    blue = lcd.RGB(42, 111, 214),
    blueBright = lcd.RGB(64, 145, 255),
    green = lcd.RGB(83, 210, 104),
    greenDim = lcd.RGB(24, 67, 34),
    amber = lcd.RGB(255, 167, 45),
    red = lcd.RGB(227, 58, 66),
    redDim = lcd.RGB(75, 15, 20),
    gold = lcd.RGB(216, 178, 83)
}

-- Liberty Ops uses a fixed cockpit palette. Keeping the header palette local
-- avoids a full ETHOS theme-signature rebuild during dashboard loading.
local colorMode = {
    bgcolor = C.bg,
    tbbgcolor = C.bg,
    titlecolor = C.white,
    cntextcolor = C.white,
    tbtextcolor = C.white,
    txbgfillcolor = C.lineDim,
    txaccentcolor = C.line,
    txfillcolor = C.green,
    fillwarncolor = C.amber,
    rssitextcolor = C.white,
    rssifillcolor = C.green,
    rssifillbgcolor = C.lineDim
}

local THEME_SECTION = "system/libertyops250"
local DEFAULTS = {
    rpm_max = 3000,
    bec_min = 6.5,
    bec_warn = 7.0,
    esctemp_warn = 100,
    esctemp_max = 140
}

local function getThemeValue(key)
    local session = rfsuite and rfsuite.session
    local prefs = session and session.modelPreferences and session.modelPreferences[THEME_SECTION]
    local value = prefs and tonumber(prefs[key])
    return value or DEFAULTS[key]
end

local function fmt(value, decimals, suffix, missing)
    if value == nil then return missing or "--" end
    if decimals == 1 then return format("%.1f", value) .. (suffix or "") end
    if decimals == 2 then return format("%.2f", value) .. (suffix or "") end
    return tostring(floor(value + 0.5)) .. (suffix or "")
end

local fontCache = {}
local function font(name)
    local cached = fontCache[name]
    if cached ~= nil then return cached or nil end
    local resolved = utils.resolveFont(name, nil)
    fontCache[name] = resolved or false
    return resolved
end

local function drawText(x, y, w, text, fontName, color, align)
    local f = font(fontName)
    if type(f) ~= "number" then return 0, 0 end
    lcd.font(f)
    lcd.color(color)
    local tw, th = lcd.getTextSize(text)
    local tx = x
    if align == "center" then tx = x + (w - tw) / 2 end
    if align == "right" then tx = x + w - tw end
    lcd.drawText(floor(tx + 0.5), floor(y + 0.5), text)
    return tw, th
end

local function header_boxes()
    local txbatt_type = 0
    if rfsuite and rfsuite.preferences and rfsuite.preferences.general then
        txbatt_type = rfsuite.preferences.general.txbatt_type or 0
    end

    if header_boxes_cache == nil or last_txbatt_type ~= txbatt_type then
        local boxes = utils.standardHeaderBoxes(colorMode, headeropts, txbatt_type)
        for _, box in ipairs(boxes) do
            box.bgcolor = "transparent"
            if box.type == "image" then
                box.type = "func"
                box.subtype = "func"
                box.paint = function(x, y, w, h)
                    local bg = colorMode.tbbgcolor or colorMode.bgcolor
                    if type(bg) == "number" then
                        lcd.color(bg)
                        lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
                    end
                    local f = font("FONT_L")
                    if type(f) ~= "number" then return end
                    lcd.font(f)
                    local a, b, c = "ETHOS ", "// ", "ROTORFLIGHT"
                    local aw = lcd.getTextSize(a)
                    local bw = lcd.getTextSize(b)
                    local cw = lcd.getTextSize(c)

                    local watermarkFont = font("FONT_XS")
                    local watermark = "MWRC"
                    local watermarkW, watermarkH = 0, 0
                    if type(watermarkFont) == "number" then
                        lcd.font(watermarkFont)
                        watermarkW, watermarkH = lcd.getTextSize(watermark)
                        lcd.font(f)
                    end

                    local titleW = aw + bw + cw
                    local dividerGap = watermarkW > 0 and 14 or 0
                    local total = titleW + dividerGap + watermarkW
                    local tx = x + (w - total) / 2
                    local ty = y + 4

                    lcd.color(C.white)
                    lcd.drawText(floor(tx), ty, a)
                    lcd.color(C.amber)
                    lcd.drawText(floor(tx + aw), ty, b)
                    lcd.color(C.white)
                    lcd.drawText(floor(tx + aw + bw), ty, c)

                    if watermarkW > 0 then
                        local dividerX = floor(tx + titleW + 6)
                        lcd.color(C.line)
                        lcd.drawLine(dividerX, y + 7, dividerX, y + h - 7)
                        lcd.font(watermarkFont)
                        lcd.color(C.red)
                        lcd.drawText(dividerX + 7, floor(y + (h - watermarkH) / 2), watermark)
                    end
                end
            end
        end
        header_boxes_cache = boxes
        last_txbatt_type = txbatt_type
    end
    return header_boxes_cache
end

local function drawPanel(x, y, w, h, title, accent)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    lcd.color(C.panel)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.lineDim)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(C.line)
    lcd.drawLine(x + 2, y + 2, x + w - 3, y + 2)
    lcd.drawLine(x + 2, y + 2, x + 2, y + h - 3)
    lcd.color(accent or C.blue)
    lcd.drawFilledRectangle(x + 3, y + 3, 3, max(1, h - 6))
    if title then drawText(x + 13, y + 8, w - 24, title, "FONT_XS", C.muted, "left") end
end

local function drawMiniBar(x, y, w, h, percent, color)
    percent = max(0, min(1, percent or 0))
    lcd.color(C.lineDim)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))
    if percent > 0 then
        lcd.color(color)
        lcd.drawFilledRectangle(floor(x), floor(y), floor(w * percent), floor(h))
    end
end

-- Tiny dashboard stars are intentionally drawn as three crossed strokes.
-- This preserves the star appearance while avoiding per-frame tables,
-- trigonometry, and hundreds of line operations on ETHOS.
local function drawStar(cx, cy, r, color)
    cx, cy, r = floor(cx), floor(cy), max(2, floor(r))
    lcd.color(color)
    lcd.drawLine(cx, cy - r, cx, cy + r)
    lcd.drawLine(cx - r, cy - 1, cx + r, cy + 1)
    lcd.drawLine(cx - r, cy + 1, cx + r, cy - 1)
end

local function drawHeliIcon(cx, cy, s, color)
    lcd.color(color)
    lcd.drawLine(cx - s, cy, cx + s, cy)
    lcd.drawLine(cx, cy - floor(s * 0.55), cx, cy + floor(s * 0.45))
    lcd.drawLine(cx - floor(s * 0.45), cy + floor(s * 0.15), cx + floor(s * 0.35), cy + floor(s * 0.15))
    lcd.drawLine(cx + floor(s * 0.35), cy + floor(s * 0.15), cx + floor(s * 0.7), cy + floor(s * 0.35))
    lcd.drawLine(cx - floor(s * 0.45), cy + floor(s * 0.15), cx - floor(s * 0.75), cy + floor(s * 0.35))
    lcd.drawLine(cx - floor(s * 0.25), cy + floor(s * 0.45), cx + floor(s * 0.35), cy + floor(s * 0.45))
end

local function governorColor(text)
    if text == "ACTIVE" then return C.green end
    if text == "IDLE" or text == "SPOOLUP" or text == "RECOVERY" then return C.amber end
    if text == "DISARMED" or text == "OFF" then return C.red end
    return C.muted
end

local NAV_TARGETS = {
    "FBL SETUP", "fbl", C.red,
    "TOOLS", "tools", C.white,
    "DATA", "data", C.blueBright,
    "FLIGHT LOGS", "logs", C.white,
    "SYSTEM", "system", C.blueBright
}
local NAV_COUNT = 5
local navRects = {}
local navEnabledState
local mainBox

local function isFblConnected()
    local session = rfsuite and rfsuite.session
    return session
        and session.isConnected == true
        and session.postConnectComplete == true
end

-- Install a tiny launch bridge without changing the RF Suite core files. The
-- bridge lets a dashboard button queue an exact RF Suite page before ETHOS
-- opens the system tool.
local function installLaunchBridge()
    local app = rfsuite and rfsuite.app
    if not app or app._libertyOpsLaunchBridgeInstalled then return app end

    local originalCreate = app.create
    if type(originalCreate) ~= "function" then return nil end

    app.create = function(...)
        local pending = app._libertyOpsPendingPage
        local result = originalCreate(...)
        if type(pending) == "table" then
            app._pendingMainMenuOpen = false
            app._pendingOpenPageOpts = pending
            if pending.menuId then app.pendingManifestMenuId = pending.menuId end
            app._libertyOpsPendingPage = nil
        end
        return result
    end

    app._libertyOpsLaunchBridgeInstalled = true
    return app
end

local function launchTarget(index)
    if not isFblConnected() then return end
    if not (system and type(system.openPage) == "function") then return end
    if not (rfsuite.sysIndex and rfsuite.sysIndex.app) then return end

    local app = installLaunchBridge()
    if not app then return end

    local page
    if index == 1 then
        page = {title = "FBL Setup", script = "manifest_menu/menu.lua", menuId = "setup_menu", openedFromShortcuts = true}
    elseif index == 2 then
        page = {title = "Tools", script = "manifest_menu/menu.lua", menuId = "tools_menu", openedFromShortcuts = true}
    elseif index == 3 then
        page = {title = "Diagnostics", script = "manifest_menu/menu.lua", menuId = "diagnostics", openedFromShortcuts = true}
    elseif index == 4 then
        page = {title = "Flight Logs", script = "logs/logs_dir.lua", openedFromShortcuts = true}
    elseif index == 5 then
        page = {title = "Settings", script = "manifest_menu/menu.lua", menuId = "settings_admin", openedFromShortcuts = true}
    else
        return
    end

    app._libertyOpsPendingPage = page
    system.openPage({system = rfsuite.sysIndex.app})
end

local function handleNavigationPress(widget, box, eventX, eventY, category, value)
    if not isFblConnected() then return end
    if type(eventX) ~= "number" or type(eventY) ~= "number" then return end

    for i = 1, NAV_COUNT do
        local base = (i - 1) * 4
        local rx, ry = navRects[base + 1], navRects[base + 2]
        local rw, rh = navRects[base + 3], navRects[base + 4]
        if rx and eventX >= rx and eventX < rx + rw and eventY >= ry and eventY < ry + rh then
            launchTarget(i)
            return true
        end
    end
end

local function refreshNavigationAvailability(enabled)
    enabled = enabled == true
    if navEnabledState == enabled then return end
    navEnabledState = enabled

    -- One full-screen touch handler replaces five extra dashboard objects.
    -- This keeps the RF Suite object count unchanged and avoids exhausting
    -- the ETHOS instruction budget while header battery widgets are painting.
    if mainBox then
        mainBox.onpress = enabled and handleNavigationPress or nil
    end

    local dashboard = rfsuite.widgets and rfsuite.widgets.dashboard
    if dashboard then
        dashboard._onpressIndicesReady = false
        dashboard.selectedBoxIndex = nil
    end
end

local function wakeup(box, telemetry)
    local c = box._cache or {}
    box._cache = c
    local getSensor = telemetry and telemetry.getSensor

    c.rpm = getSensor and getSensor("rpm") or nil
    c.throttle = getSensor and getSensor("throttle_percent") or nil
    c.rate = getSensor and getSensor("rate_profile") or nil
    c.pid = getSensor and getSensor("pid_profile") or nil
    c.voltage = getSensor and getSensor("voltage") or nil
    c.fuel = getSensor and getSensor("smartfuel") or nil
    c.consumed = getSensor and getSensor("smartconsumption") or nil
    c.bec = getSensor and getSensor("bec_voltage") or nil
    c.esc = getSensor and getSensor("temp_esc") or nil
    c.link = getSensor and getSensor("link") or nil

    local govRaw = getSensor and getSensor("governor")
    if govRaw == nil then
        c.governor = "WAITING"
    else
        c.governor = rfsuite.utils.getGovernorState(govRaw)
    end

    c.govColor = governorColor(c.governor)
    c.fuelColor = c.fuel and (c.fuel <= 25 and C.red or (c.fuel <= 50 and C.amber or C.green)) or C.muted
    c.becColor = c.bec and (c.bec < getThemeValue("bec_min") and C.red or (c.bec < getThemeValue("bec_warn") and C.amber or C.green)) or C.muted
    c.escColor = c.esc and (c.esc >= getThemeValue("esctemp_max") and C.red or (c.esc >= getThemeValue("esctemp_warn") and C.amber or C.green)) or C.muted
    c.linkColor = c.link and (c.link < 50 and C.amber or C.green) or C.muted
    c.controllerConnected = isFblConnected()
    refreshNavigationAvailability(c.controllerConnected)
    return c
end

local function drawBadgePanel(x, y, w, h)
    drawPanel(x, y, w, h, nil, C.blue)
    drawHeliIcon(floor(x + 42), floor(y + 30), 18, C.white)
    drawText(x + 70, y + 10, w - 82, "ROTORFLIGHT", "FONT_S", C.white, "left")
    drawText(x + 70, y + 33, w - 82, "RF2.3.0", "FONT_XS", C.muted, "left")
    drawText(x + 10, y + 78, w - 20, "AMERICA", "FONT_STD", C.white, "center")
    drawText(x + 10, y + 108, w - 20, "250", "FONT_XXL", C.white, "center")

    local cx = x + w / 2
    local cy = y + h - 30
    local rx = w * 0.95
    local ry = 42
    drawStar(cx - 0.31 * rx, cy - 0.34 * ry, 3, C.red)
    drawStar(cx - 0.27 * rx, cy - 0.52 * ry, 3, C.white)
    drawStar(cx - 0.20 * rx, cy - 0.67 * ry, 3, C.blueBright)
    drawStar(cx - 0.11 * rx, cy - 0.77 * ry, 3, C.red)
    drawStar(cx,             cy - 0.80 * ry, 3, C.white)
    drawStar(cx + 0.11 * rx, cy - 0.77 * ry, 3, C.blueBright)
    drawStar(cx + 0.20 * rx, cy - 0.67 * ry, 3, C.red)
    drawStar(cx + 0.27 * rx, cy - 0.52 * ry, 3, C.white)
    drawStar(cx + 0.31 * rx, cy - 0.34 * ry, 3, C.blueBright)
    drawStar(cx + 0.27 * rx, cy - 0.16 * ry, 3, C.red)
    drawStar(cx + 0.18 * rx, cy - 0.02 * ry, 3, C.white)
    drawStar(cx,             cy + 0.04 * ry, 3, C.blueBright)
    drawStar(cx - 0.18 * rx, cy - 0.02 * ry, 3, C.red)
end

local function drawFooterStars(x, y, w, h)
    drawStar(x + 0.20 * w, y + 0.25 * h, 3, C.white)
    drawStar(x + 0.40 * w, y + 0.25 * h, 3, C.white)
    drawStar(x + 0.60 * w, y + 0.25 * h, 3, C.white)
    drawStar(x + 0.80 * w, y + 0.25 * h, 3, C.white)
    drawStar(x + 0.10 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.30 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.50 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.70 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.90 * w, y + 0.50 * h, 3, C.white)
    drawStar(x + 0.20 * w, y + 0.75 * h, 3, C.white)
    drawStar(x + 0.40 * w, y + 0.75 * h, 3, C.white)
    drawStar(x + 0.60 * w, y + 0.75 * h, 3, C.white)
    drawStar(x + 0.80 * w, y + 0.75 * h, 3, C.white)
end

local function drawFooterBanner(x, y, w, h)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    local cantonW = floor(w * 0.40)

    lcd.color(lcd.RGB(5, 13, 35))
    lcd.drawFilledRectangle(x, y, w, h)

    -- Blue canton with the 13 original-colony stars.
    lcd.color(lcd.RGB(9, 27, 70))
    lcd.drawFilledRectangle(x, y, cantonW, h)
    drawFooterStars(x + 8, y + 3, cantonW - 16, h - 16)

    -- Red and white flag stripes on the right side.
    local stripeH = max(3, floor(h / 7))
    for i = 0, 6 do
        lcd.color((i % 2 == 0) and C.red or C.white)
        lcd.drawFilledRectangle(x + cantonW, y + i * stripeH, w - cantonW, stripeH)
    end

    -- Keep the flag continuous.  A small text shadow provides contrast without
    -- covering the canton or stripes with a large black rectangle.
    local titleY = y + floor(h * 0.20)
    drawText(x + 1, titleY + 1, w, "AMERICA 250", "FONT_L", C.bg, "center")
    drawText(x, titleY, w, "AMERICA 250", "FONT_L", C.white, "center")

    local subtitleY = y + h - 17
    drawText(x + 1, subtitleY + 1, w, "13 ORIGINAL COLONIES  |  250 YEARS OF LIBERTY", "FONT_XXS", C.bg, "center")
    drawText(x, subtitleY, w, "13 ORIGINAL COLONIES  |  250 YEARS OF LIBERTY", "FONT_XXS", C.white, "center")
end

local function drawNavIcon(x, y, w, h, kind, color)
    local cx = floor(x + w / 2)
    local cy = floor(y + h / 2 - 5)
    lcd.color(color)

    if kind == "fbl" then
        drawHeliIcon(cx, cy, 14, color)
    elseif kind == "tools" then
        lcd.drawRectangle(cx - 10, cy - 7, 20, 15, 1)
        lcd.drawLine(cx - 5, cy - 10, cx + 5, cy - 10)
        lcd.drawLine(cx - 5, cy - 10, cx - 5, cy - 7)
        lcd.drawLine(cx + 5, cy - 10, cx + 5, cy - 7)
    elseif kind == "data" then
        lcd.drawFilledRectangle(cx - 10, cy + 1, 5, 8)
        lcd.drawFilledRectangle(cx - 2, cy - 5, 5, 14)
        lcd.drawFilledRectangle(cx + 6, cy - 11, 5, 20)
    elseif kind == "logs" then
        lcd.drawRectangle(cx - 10, cy - 11, 20, 22, 1)
        for i = 0, 2 do
            lcd.drawLine(cx - 5, cy - 6 + i * 6, cx + 6, cy - 6 + i * 6)
            lcd.drawRectangle(cx - 8, cy - 7 + i * 6, 2, 2, 1)
        end
    elseif kind == "system" then
        lcd.drawRectangle(cx - 8, cy - 8, 16, 16, 1)
        lcd.drawRectangle(cx - 3, cy - 3, 6, 6, 1)
        lcd.drawLine(cx, cy - 12, cx, cy - 8)
        lcd.drawLine(cx, cy + 8, cx, cy + 12)
        lcd.drawLine(cx - 12, cy, cx - 8, cy)
        lcd.drawLine(cx + 8, cy, cx + 12, cy)
    end
end

local function drawNavButton(x, y, w, h, label, kind, accent, enabled)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    enabled = enabled == true
    local edge = enabled and accent or C.lineDim
    local icon = enabled and accent or C.muted
    local labelColor = enabled and C.white or C.muted

    lcd.color(enabled and C.panel or C.bg)
    lcd.drawFilledRectangle(x, y, w, h)
    lcd.color(C.lineDim)
    lcd.drawRectangle(x, y, w, h, 1)
    lcd.color(edge)
    lcd.drawLine(x + 2, y + 2, x + w - 3, y + 2)
    lcd.drawLine(x + 2, y + 2, x + 2, y + h - 3)
    drawNavIcon(x, y, w, h - 14, kind, icon)
    drawText(x + 4, y + h - 17, w - 8, label, "FONT_XXS", labelColor, "center")
end

local function paint(x, y, w, h, box, c)
    x, y = utils.applyOffset(x, y, box)
    c = c or box._cache or {}
    lcd.color(C.bg)
    lcd.drawFilledRectangle(floor(x), floor(y), floor(w), floor(h))

    local pad = 10
    local footerH = min(58, floor(h * 0.145))
    local navH = min(52, floor(h * 0.13))
    local bottomGap = 6
    local footerY = y + h - footerH - 4
    local navY = footerY - navH - bottomGap
    local contentY = y + 6
    local contentH = navY - contentY - 8
    local tileH = 48
    local tileGap = 7
    local upperH = contentH - tileH - tileGap
    local leftW = floor(w * 0.27)
    local gap = 8
    local rightW = floor(w * 0.20)
    local modeW = floor(w * 0.20)
    local governorW = w - pad * 2 - leftW - rightW - modeW - gap * 3

    local leftX = x + pad
    local govX = leftX + leftW + gap
    local modeX = govX + governorW + gap
    local powerX = modeX + modeW + gap

    drawBadgePanel(leftX, contentY, leftW, upperH)

    drawPanel(govX, contentY, governorW, upperH, "GOVERNOR", c.govColor or C.muted)
    drawText(govX + 12, contentY + 45, governorW - 24, "RPM", "FONT_XS", C.muted, "center")
    drawText(govX + 10, contentY + 72, governorW - 20, fmt(c.rpm, 0, "", "--"), "FONT_XXL", C.white, "center")
    lcd.color(C.lineDim)
    lcd.drawLine(floor(govX + 14), floor(contentY + upperH * 0.60), floor(govX + governorW - 14), floor(contentY + upperH * 0.60))
    drawText(govX + 12, contentY + upperH * 0.65, governorW - 24, "THR %", "FONT_XS", C.muted, "center")
    drawText(govX + 12, contentY + upperH * 0.76, governorW - 24, fmt(c.throttle, 0, "", "--"), "FONT_XL", C.white, "center")
    drawMiniBar(govX + 14, contentY + upperH - 18, governorW - 28, 6, (c.throttle or 0) / 100, C.green)

    drawPanel(modeX, contentY, modeW, upperH, "FLIGHT MODE", C.blue)
    drawText(modeX + 10, contentY + 48, modeW - 20, "R" .. fmt(c.rate, 0, "", "-") .. " / P" .. fmt(c.pid, 0, "", "-"), "FONT_L", C.white, "center")
    lcd.color(C.lineDim)
    lcd.drawLine(floor(modeX + 12), floor(contentY + upperH * 0.48), floor(modeX + modeW - 12), floor(contentY + upperH * 0.48))
    drawText(modeX + 10, contentY + upperH * 0.55, modeW - 20, "GOVERNOR", "FONT_XS", C.muted, "center")
    drawText(modeX + 10, contentY + upperH * 0.68, modeW - 20, c.governor or "WAITING", "FONT_STD", c.govColor or C.muted, "center")

    drawPanel(powerX, contentY, rightW, floor(upperH * 0.42), "VOLTAGE", C.green)
    drawText(powerX + 12, contentY + 44, rightW - 24, fmt(c.voltage, 1, " V", "--"), "FONT_XL", C.white, "center")
    drawMiniBar(powerX + 14, contentY + floor(upperH * 0.42) - 17, rightW - 28, 6, c.voltage and min(1, c.voltage / 60) or 0, C.green)

    local fuelY = contentY + floor(upperH * 0.42) + gap
    local fuelH = contentH - floor(upperH * 0.42) - gap
    drawPanel(powerX, fuelY, rightW, fuelH, "SMART FUEL", c.fuelColor or C.muted)
    drawText(powerX + 12, fuelY + 35, rightW - 24, fmt(c.fuel, 0, "%", "--"), "FONT_XL", c.fuelColor or C.muted, "center")
    drawText(powerX + 12, fuelY + 79, rightW - 24, "USED", "FONT_XS", C.muted, "center")
    drawText(powerX + 12, fuelY + 99, rightW - 24, fmt(c.consumed, 0, " mAh", "--"), "FONT_STD", C.white, "center")
    drawMiniBar(powerX + 14, fuelY + fuelH - 18, rightW - 28, 6, c.fuel and c.fuel / 100 or 0, c.fuelColor or C.muted)

    local tilesY = contentY + upperH + tileGap
    local tileW = floor((w - pad * 2 - tileGap * 3) / 4)
    local tx1 = x + pad
    local tx2 = tx1 + tileW + tileGap
    local tx3 = tx2 + tileW + tileGap
    local tx4 = tx3 + tileW + tileGap
    drawPanel(tx1, tilesY, tileW, tileH, "BEC", c.becColor)
    drawText(tx1 + 12, tilesY + 20, tileW - 24, fmt(c.bec, 1, " V", "--"), "FONT_STD", C.white, "right")
    drawPanel(tx2, tilesY, tileW, tileH, "ESC TEMP", c.escColor)
    drawText(tx2 + 12, tilesY + 20, tileW - 24, fmt(c.esc, 0, " C", "--"), "FONT_STD", C.white, "right")
    drawPanel(tx3, tilesY, tileW, tileH, "LINK", c.linkColor)
    drawText(tx3 + 12, tilesY + 20, tileW - 24, fmt(c.link, 0, "%", "--"), "FONT_STD", C.white, "right")
    drawPanel(tx4, tilesY, tileW, tileH, "PACK", C.blueBright)
    drawText(tx4 + 12, tilesY + 20, tileW - 24, fmt(c.voltage, 1, " V", "--"), "FONT_STD", C.white, "right")

    -- Five cockpit-style RF Suite shortcuts. They are dimmed and have no
    -- onpress callback until the FBL has completed its connection handshake.
    local navGap = 7
    local navW = floor((w - pad * 2 - navGap * 4) / 5)
    for i = 1, NAV_COUNT do
        local itemBase = (i - 1) * 3
        local rectBase = (i - 1) * 4
        local nx = x + pad + (i - 1) * (navW + navGap)
        navRects[rectBase + 1] = nx
        navRects[rectBase + 2] = navY
        navRects[rectBase + 3] = navW
        navRects[rectBase + 4] = navH
        drawNavButton(nx, navY, navW, navH, NAV_TARGETS[itemBase + 1], NAV_TARGETS[itemBase + 2], NAV_TARGETS[itemBase + 3], c.controllerConnected)
    end

    -- Fully Lua-drawn flag footer with a visible blue canton and 13 stars.
    drawFooterBanner(x + pad, footerY, w - pad * 2, footerH)
end

local layout = {
    cols = 12,
    rows = 12,
    padding = 0,
    selectcolor = C.blueBright,
    selectborder = 2
}
local screenBorderStyle = {enabled = false}
local boxes_cache

local function boxes()
    if boxes_cache == nil then
        mainBox = {
            col = 1, row = 1, colspan = 12, rowspan = 12,
            type = "func", subtype = "func",
            wakeup = wakeup,
            paint = paint,
            bgcolor = "transparent"
        }
        boxes_cache = {mainBox}
        refreshNavigationAvailability(isFblConnected())
    end
    return boxes_cache
end

return {
    layout = layout,
    boxes = boxes,
    header_boxes = header_boxes,
    header_layout = header_layout,
    screenBorderStyle = screenBorderStyle,
    scheduler = {spread_scheduling = true, spread_scheduling_paint = false, spread_ratio = 0.82}
}
