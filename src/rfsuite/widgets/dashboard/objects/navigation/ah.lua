--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

--[[
    wakeupinterval      : number   -- Optional wakeup interval in seconds (default: 0.2)
    pixelsperdeg        : number   -- Pixels per degree for pitch & compass (default: 2.0)
    dynamicscalemin     : number   -- Minimum scale factor (default: 1.05)
    dynamicscalemax     : number   -- Maximum scale factor (default: 1.95)
    showarc             : bool     -- Show arc markers (default: true)
    showladder          : bool     -- Show pitch ladder (default: true)
    showcompass         : bool     -- Show compass ribbon (default: true)
    showaltitude        : bool     -- Show altitude bar on right (default: false)
    showgroundspeed           : bool     -- Show groundspeed bar on left (default: false)
    arccolor            : color    -- Color for arc markings (default: white)
    laddercolor         : color    -- Color for pitch ladder (default: white)
    compasscolor        : color    -- Color for compass (default: white)
    crosshaircolor      : color    -- Color for central cross marker (default: white)
    altitudecolor       : color    -- Color for altitude bar (default: white)
    groundspeedcolor          : color    -- Color for groundspeed bar (default: white)
    altitudemin         : number   -- Minimum displayed altitude (default: 0)
    altitudemax         : number   -- Maximum displayed altitude (default: 200)
    groundspeedmin            : number   -- Minimum displayed groundspeed (default: 0)
    groundspeedmax            : number   -- Maximum displayed groundspeed (default: 100)
]]

local rfsuite = require("rfsuite")
local lcd = lcd

local floor = math.floor
local min = math.min
local max = math.max
local sin = math.sin
local cos = math.cos
local format = string.format
local ipairs = ipairs
local tostring = tostring

local render = {}
local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam
local resolveThemeColor = utils.resolveThemeColor
local ARC_MARK_ANGLES = {-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60}
local COMPASS_LABELS = {[0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW"}
local DEFAULT_WIDGET_COLOR = lcd.RGB(255, 255, 255)
local SKY_COLOR = lcd.RGB(70, 130, 180)
local GROUND_COLOR = lcd.RGB(160, 82, 45)
local COMPASS_BOX_BG_COLOR = lcd.RGB(0, 0, 0)

function render.invalidate(box) box._cfg = nil end

local function rotate(px, py, cx, cy, angle)
    local s = sin(angle)
    local c = cos(angle)
    px, py = px - cx, py - cy
    local xnew = px * c - py * s
    local ynew = px * s + py * c
    return xnew + cx, ynew + cy
end

local function ensureCfg(box)
    local theme_version = (rfsuite and rfsuite.theme and rfsuite.theme.version) or 0
    local param_version = box._param_version or 0
    local cfg = box._cfg
    if (not cfg) or (cfg._theme_version ~= theme_version) or (cfg._param_version ~= param_version) then
        cfg = {}
        cfg._theme_version = theme_version
        cfg._param_version = param_version

        cfg.ppd = getParam(box, "pixelsperdeg") or 2.0
        cfg.dMin = getParam(box, "dynamicscalemin") or 1.05
        cfg.dMax = getParam(box, "dynamicscalemax") or ((getParam(box, "dynamicscalemin") or 1.05) + 0.9)

        cfg.showarc = getParam(box, "showarc") ~= false
        cfg.showladder = getParam(box, "showladder") ~= false
        cfg.showcompass = getParam(box, "showcompass") ~= false
        cfg.showaltitude = getParam(box, "showaltitude") ~= false
        cfg.showgroundspeed = getParam(box, "showgroundspeed") ~= false

        cfg.arccolor = resolveThemeColor("arccolor", getParam(box, "arccolor") or DEFAULT_WIDGET_COLOR)
        cfg.laddercolor = resolveThemeColor("laddercolor", getParam(box, "laddercolor") or DEFAULT_WIDGET_COLOR)
        cfg.compasscolor = resolveThemeColor("compasscolor", getParam(box, "compasscolor") or DEFAULT_WIDGET_COLOR)
        cfg.crosshaircolor = resolveThemeColor("crosshaircolor", getParam(box, "crosshaircolor") or DEFAULT_WIDGET_COLOR)
        cfg.altitudecolor = resolveThemeColor("altitudecolor", getParam(box, "altitudecolor") or DEFAULT_WIDGET_COLOR)
        cfg.groundspeedcolor = resolveThemeColor("groundspeedcolor", getParam(box, "groundspeedcolor") or DEFAULT_WIDGET_COLOR)

        cfg.altitudemin = getParam(box, "altitudemin") or 0
        cfg.altitudemax = getParam(box, "altitudemax") or 200
        cfg.groundspeedmin = getParam(box, "groundspeedmin") or 0
        cfg.groundspeedmax = getParam(box, "groundspeedmax") or 100

        box._cfg = cfg
    end
    return box._cfg
end

function render.dirty(box)
    local d = box._dyn
    if not d then return false end
    local l = box._last
    if not l then
        l = {}
        box._last = l
    end
    if d.pitch ~= l.pitch or d.roll ~= l.roll or d.yaw ~= l.yaw or d.altitude ~= l.altitude or d.groundspeed ~= l.groundspeed then
        l.pitch = d.pitch
        l.roll = d.roll
        l.yaw = d.yaw
        l.altitude = d.altitude
        l.groundspeed = d.groundspeed
        return true
    end
    return false
end

function render.wakeup(box)
    ensureCfg(box)

    local telemetry = rfsuite.tasks.telemetry
    if not telemetry then return end
    local getSensor = telemetry.getSensor

    local pitch = getSensor("attpitch") or 0
    local roll = getSensor("attroll") or 0
    local yaw = getSensor("attyaw") or 0
    local altitude = getSensor("altitude") or 20
    local groundspeed = getSensor("groundspeed") or 20

    local d = box._dyn
    if not d then
        d = {}
        box._dyn = d
    end
    d.pitch = pitch
    d.roll = roll
    d.yaw = yaw
    d.altitude = altitude
    d.groundspeed = groundspeed
end

function render.paint(x, y, w, h, box)
    local c = box._cfg;
    if not c then return end
    local d = box._dyn;
    if not d then return end

    local pitch, roll, yaw = d.pitch, d.roll, d.yaw
    local ppd = c.ppd
    local cx, cy = x + w / 2, y + h / 2

    lcd.setClipping(x, y, w, h)

    lcd.color(pitch >= 0 and SKY_COLOR or GROUND_COLOR)
    lcd.drawFilledRectangle(x, y, w, h)

    local horizonY = cy + pitch * ppd
    local rollRad = math.rad(roll)

    local xL, yL = rotate(cx - 3 * w, horizonY, cx, horizonY, rollRad)
    local xR, yR = rotate(cx + 3 * w, horizonY, cx, horizonY, rollRad)

    local nx, ny = -sin(rollRad), cos(rollRad)

    local overlayColor = (pitch >= 0) and GROUND_COLOR or SKY_COLOR
    lcd.color(overlayColor)

    local BIG = 4 * max(w, h)
    local sx, sy
    if pitch >= 0 then
        sx, sy = nx * BIG, ny * BIG
    else
        sx, sy = -nx * BIG, -ny * BIG
    end

    local p1x, p1y = xL + sx, yL + sy
    local p2x, p2y = xR + sx, yR + sy
    local p3x, p3y = xR, yR
    local p4x, p4y = xL, yL

    lcd.drawFilledTriangle(p1x, p1y, p2x, p2y, p3x, p3y)
    lcd.drawFilledTriangle(p1x, p1y, p3x, p3y, p4x, p4y)

    lcd.color(c.crosshaircolor)
    lcd.drawLine(cx - 5, cy, cx + 5, cy)
    lcd.drawLine(cx, cy - 5, cx, cy + 5)
    lcd.drawCircle(cx, cy, 3)

    if c.showarc then
        lcd.color(c.arccolor)
        local arcR = w * 0.4
        for _, ang in ipairs(ARC_MARK_ANGLES) do
            local rad = math.rad(ang)
            local x1 = cx + arcR * sin(rad)
            local y1 = y + 10 + arcR * (1 - cos(rad))
            local x2 = cx + (arcR - 6) * sin(rad)
            local y2 = y + 10 + (arcR - 6) * (1 - cos(rad))
            lcd.drawLine(x1, y1, x2, y2)
        end
        lcd.drawFilledTriangle(cx, y + 5, cx - 6, y + 15, cx + 6, y + 15)
    end

    if c.showladder then
        lcd.color(c.laddercolor)
        for ang = -90, 90, 10 do
            local off = (pitch - ang) * ppd
            local py = cy + off
            if py > y - 40 and py < y + h + 40 then
                local major = (ang % 20 == 0)
                local len = major and 25 or 15
                local x1, y1 = rotate(cx - len, py, cx, cy, math.rad(roll))
                local x2, y2 = rotate(cx + len, py, cx, cy, math.rad(roll))
                lcd.drawLine(x1, y1, x2, y2)
                if major then
                    local lbl = tostring(ang)
                    local lx, ly = rotate(cx - len - 10, py - 4, cx, cy, math.rad(roll))
                    local rx, ry = rotate(cx + len + 2, py - 4, cx, cy, math.rad(roll))
                    lcd.drawText(lx, ly, lbl, RIGHT)
                    lcd.drawText(rx, ry, lbl, LEFT)
                end
            end
        end
    end

    if c.showcompass then
        lcd.color(c.compasscolor)
        local heading = floor((yaw + 360) % 360)
        local compassY = y + h - 24
        for ang = -90, 90, 10 do
            local hdg = (heading + ang + 360) % 360
            local px = cx + ang * ppd
            if px > x and px < x + w then
                local th = (hdg % 30 == 0) and 8 or 4
                lcd.drawLine(px, compassY, px, compassY - th)
                if hdg % 30 == 0 then lcd.drawText(px, compassY - th - 8, COMPASS_LABELS[hdg] or tostring(hdg), CENTERED + FONT_XS) end
            end
        end
        lcd.drawFilledTriangle(cx, compassY + 1, cx - 5, compassY - 7, cx + 5, compassY - 7)

        local bw, bh = 60, 14
        local bx, by = cx - bw / 2, compassY + 6
        if by + bh < y + h then
            lcd.color(COMPASS_BOX_BG_COLOR);
            lcd.drawFilledRectangle(bx, by, bw, bh)
            lcd.color(c.compasscolor);
            lcd.drawRectangle(bx, by, bw, bh)
            lcd.drawText(cx, by + 1, format("%03d° %s", heading, COMPASS_LABELS[heading - (heading % 45)] or (heading .. "°")), CENTERED + FONT_XS)
        end
    end

    if c.showaltitude then
        lcd.color(c.altitudecolor)
        local barX = x + w - 10
        local barY = y + 5
        local barH = h - 10
        local fillH = floor((d.altitude - c.altitudemin) / (c.altitudemax - c.altitudemin) * barH)
        fillH = max(0, min(barH, fillH))
        lcd.drawRectangle(barX, barY, 6, barH)
        lcd.drawFilledRectangle(barX, barY + barH - fillH, 6, fillH)
        lcd.font(FONT_XS)
        local label = format("%d m", floor(d.altitude))
        lcd.drawText(barX - 4, barY + barH - fillH - 6, label, RIGHT)
    end

    if c.showgroundspeed then
        lcd.color(c.groundspeedcolor)
        local barX = x + 4
        local barY = y + 5
        local barH = h - 10
        local fillH = floor((d.groundspeed - c.groundspeedmin) / (c.groundspeedmax - c.groundspeedmin) * barH)
        fillH = max(0, min(barH, fillH))
        lcd.drawRectangle(barX, barY, 6, barH)
        lcd.drawFilledRectangle(barX, barY + barH - fillH, 6, fillH)
        lcd.font(FONT_XS)
        local label = format("%d knots", floor(d.groundspeed))
        lcd.drawText(barX + 10, barY + barH - fillH - 6, label, LEFT)
    end

    lcd.setClipping(0, 0, lcd.getWindowSize())
end

render.scheduler = 0.01

return render
