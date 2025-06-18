--[[
    Attitude Horizon Widget (AH)
    Configurable Parameters (box table fields):
    ------------------------------------------------
    wakeupInterval      : number   -- Optional wakeup interval in seconds (default: 0.2)
    imagePath           : string   -- Path to horizon image (default: "widgets/dashboard/gfx/navigation/ahorizon.png")
    pixelsPerDeg        : number   -- Pixels per degree for pitch & compass (default: 2.0)
    dynamicScaleMin     : number   -- Minimum scale factor (default: 1.05)
    dynamicScaleMax     : number   -- Maximum scale factor (default: 1.95)
]]

local render    = {}
local utils     = rfsuite.widgets.dashboard.utils
local getParam  = utils.getParam
local loadImage = rfsuite.utils.loadImage
local lastPitch, lastRoll, lastYaw = 0, 0, 0

-- Rotate helper: rotates point (px,py) around center (cx,cy) by angle (radians)
local function rotate(px, py, cx, cy, angle)
    local s = math.sin(angle)
    local c = math.cos(angle)
    px, py = px - cx, py - cy
    local xnew = px * c - py * s
    local ynew = px * s + py * c
    return xnew + cx, ynew + cy
end

local DEFAULT_IMAGE_PATH = "widgets/dashboard/gfx/navigation/ahorizon.png"

-- Determine if widget needs repaint based solely on wakeup-flag
function render.dirty(box)
    return box._dirty == true 
end

-- Perform sensor reads, config, and cache values; polls at configured interval
function render.wakeup(box, telemetry)
    local interval = getParam(box, "wakeupInterval") or 0.2
    box._lastWakeup = box._lastWakeup or 0
    local now = rfsuite.clock
    if now - box._lastWakeup < interval then return end
    box._lastWakeup = now

    if not box._image then
        local path = getParam(box, "imagePath") or DEFAULT_IMAGE_PATH
        box._image = loadImage(path)
        local iw, ih = box._image:width(), box._image:height()
        box._config = {
            ppd       = getParam(box, "pixelsPerDeg") or 2.0,
            dMin      = getParam(box, "dynamicScaleMin") or 1.05,
            dMax      = getParam(box, "dynamicScaleMax") or ((getParam(box, "dynamicScaleMin") or 1.05) + 0.9),
            iw        = iw,
            ih        = ih,
            imageDiag = math.sqrt(iw * iw + ih * ih),
        }
    end

    local getSensor = telemetry.getSensor
    local pitch = getSensor("attpitch") or 0
    local roll  = getSensor("attroll")  or 0
    local yaw   = getSensor("attyaw")   or 0

    local prev = box._last or {}
    if prev.pitch ~= pitch or prev.roll ~= roll or prev.yaw ~= yaw then
        box._dirty = true
    else
        box._dirty = false
    end

    box._cache = { pitch = pitch, roll = roll, yaw = yaw }
    box._last  = { pitch = pitch, roll = roll, yaw = yaw }
end

-- Draw the attitude horizon using cached values and static config
function render.paint(x, y, w, h, box)

    local cfg = box._config
    local img = box._image
    local c   = box._cache
    if not img or not cfg or not c then return end


    local ppd, dMin, dMax = cfg.ppd, cfg.dMin, cfg.dMax
    local pitch, roll, yaw = c.pitch, c.roll, c.yaw

    lcd.setClipping(x, y, w, h)

    local maxOff     = ppd * 90
    local paddedH    = h + 2 * maxOff
    local paddedDiag = math.sqrt(w * w + paddedH * paddedH)
    local scale      = (paddedDiag / cfg.imageDiag) * (dMin + (math.max(math.abs(pitch), math.abs(roll)) / 90) * (dMax - dMin))

    local drawW      = cfg.iw * scale
    local drawH      = cfg.ih * scale
    local cx, cy     = x + w / 2, y + h / 2
    local drawX      = cx - drawW / 2
    local drawY      = cy - drawH / 2 + pitch * ppd

    lcd.drawBitmap(drawX, drawY, img:rotate(roll), drawW, drawH)

    lcd.color(lcd.RGB(255,255,255))
    lcd.drawLine(cx-5, cy, cx+5, cy)
    lcd.drawLine(cx, cy-5, cx, cy+5)
    lcd.drawCircle(cx, cy, 3)

    local arcR = w * 0.4
    for _, ang in ipairs({-60,-45,-30,-20,-10,0,10,20,30,45,60}) do
        local rad = math.rad(ang)
        local x1  = cx + arcR * math.sin(rad)
        local y1  = y + 10 + arcR * (1 - math.cos(rad))
        local x2  = cx + (arcR-6) * math.sin(rad)
        local y2  = y + 10 + (arcR-6) * (1 - math.cos(rad))
        lcd.drawLine(x1, y1, x2, y2)
    end
    lcd.drawFilledTriangle(cx, y+5, cx-6, y+15, cx+6, y+15)

    for ang = -90, 90, 10 do
        local off = (pitch - ang) * ppd
        local py  = cy + off
        if py > y-40 and py < y+h+40 then
            local major = (ang % 20 == 0)
            local len   = major and 25 or 15
            local x1,y1 = rotate(cx-len, py, cx, cy, roll)
            local x2,y2 = rotate(cx+len, py, cx, cy, roll)
            lcd.drawLine(x1, y1, x2, y2)
            if major then
                local lbl = tostring(ang)
                local lx,ly = rotate(cx-len-10, py-4, cx, cy, roll)
                local rx,ry = rotate(cx+len+2, py-4, cx, cy, roll)
                lcd.drawText(lx, ly, lbl, RIGHT)
                lcd.drawText(rx, ry, lbl, LEFT)
            end
        end
    end

    local heading  = math.floor((yaw + 360) % 360)
    local compassY = y + h - 24
    local labels   = {[0]="N",[45]="NE",[90]="E",[135]="SE",[180]="S",[225]="SW",[270]="W",[315]="NW"}
    for ang = -90, 90, 10 do
        local hdg = (heading + ang + 360) % 360
        local px  = cx + ang * ppd
        if px > x and px < x+w then
            local th = (hdg % 30 == 0) and 8 or 4
            lcd.drawLine(px, compassY, px, compassY-th)
            if hdg % 30 == 0 then
                lcd.drawText(px, compassY-th-8, labels[hdg] or tostring(hdg), CENTERED+FONT_XS)
            end
        end
    end
    lcd.drawFilledTriangle(cx, compassY+1, cx-5, compassY-7, cx+5, compassY-7)

    local bw, bh = 60, 14
    local bx, by = cx - bw/2, compassY + 6
    if by + bh < y + h then
        lcd.color(lcd.RGB(0,0,0)); lcd.drawFilledRectangle(bx, by, bw, bh)
        lcd.color(lcd.RGB(255,255,255)); lcd.drawRectangle(bx, by, bw, bh)
        lcd.drawText(cx, by+1, string.format("%03d° %s", heading, labels[heading - (heading % 45)] or (heading.."°")), CENTERED+FONT_XS)
    end

    lcd.setClipping(0,0, lcd.getWindowSize())
    box._dirty = false
end

return render
