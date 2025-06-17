--[[
    Attitude Horizon Widget (AH)
    Configurable Parameters (box table fields):
    ------------------------------------------------
    wakeupInterval      : number   -- Optional wakeup interval in seconds (default: 0.2)
    tolPitch            : number   -- Dirty tolerance for pitch change (default: 0.1)
    tolRoll             : number   -- Dirty tolerance for roll change (default: 0.1)
    tolYaw              : number   -- Dirty tolerance for yaw change (default: 0.1)
    imagePath           : string   -- Path to horizon image (default: "widgets/dashboard/gfx/navigation/ahorizon.png")
    pixelsPerDeg        : number   -- Pixels per degree for pitch & compass (default: 2.0)
    dynamicScaleMin     : number   -- Minimum scale factor (default: 1.05)
    dynamicScaleMax     : number   -- Maximum scale factor (default: 1.95)
]]

local render       = {}
local utils        = rfsuite.widgets.dashboard.utils
local getParam     = utils.getParam
local loadImage    = rfsuite.utils.loadImage

-- Rotate helper: rotates point (px,py) around center (cx,cy) by angle (radians)
local function rotate(px, py, cx, cy, angle)
    local s = math.sin(angle)
    local c = math.cos(angle)
    px, py = px - cx, py - cy
    local xnew = px * c - py * s
    local ynew = px * s + py * c
    return xnew + cx, ynew + cy
end

-- Initialize default image path
local DEFAULT_IMAGE_PATH = "widgets/dashboard/gfx/navigation/ahorizon.png"

-- Determine if widget needs repaint based on cached values
function render.dirty(box)
    if not box._last then return true end
    local c, l = box._cache or {}, box._last or {}
    local tolP = getParam(box, "tolPitch") or 0.1
    local tolR = getParam(box, "tolRoll")  or 0.1
    local tolY = getParam(box, "tolYaw")   or 0.1
    return math.abs((c.pitch or 0) - (l.pitch or 0)) > tolP
        or math.abs((c.roll  or 0) - (l.roll  or 0)) > tolR
        or math.abs((c.yaw   or 0) - (l.yaw   or 0)) > tolY
end

-- Perform sensor reads, configuration and cache values; polls at configured interval
function render.wakeup(box, telemetry)
    box._wakeupInterval = getParam(box, "wakeupInterval") or 0.2
    box._lastWakeup     = box._lastWakeup or 0
    local now = rfsuite.clock
    if now - box._lastWakeup < box._wakeupInterval then return end
    box._lastWakeup = now

    -- Lazy-load horizon image once and compute static geometry
    if not box._image then
        local path = getParam(box, "imagePath") or DEFAULT_IMAGE_PATH
        box._image = loadImage(path)
        local iw, ih = box._image:width(), box._image:height()
        box._config = {
            ppd       = getParam(box, "pixelsPerDeg") or 2.0,
            dMin      = getParam(box, "dynamicScaleMin") or 1.05,
            dMax      = getParam(box, "dynamicScaleMax") or ( (getParam(box, "dynamicScaleMin") or 1.05) + 0.9 ),
            iw        = iw,
            ih        = ih,
            imageDiag = math.sqrt(iw * iw + ih * ih),
        }
    end

    -- Read attitude sensors and cache readings
    local getSensor = telemetry.getSensor
    local pitch = getSensor("attpitch") or 0
    local roll  = getSensor("attroll")  or 0
    local yaw   = getSensor("attyaw")   or 0
    box._cache = { pitch = pitch, roll = roll, yaw = yaw }
end

-- Draw the attitude horizon using cached values and configuration
function render.paint(x, y, w, h, box)
    local c = box._cache or {}
    local cfg = box._config
    local img = box._image
    if not img or not cfg then return end

    local ppd, dMin, dMax = cfg.ppd, cfg.dMin, cfg.dMax
    local pitch, roll, yaw = c.pitch, c.roll, c.yaw

    lcd.setClipping(x, y, w, h)

    -- Compute scaling
    local maxOffset = ppd * 90
    local paddedH    = h + 2 * maxOffset
    local paddedDiag = math.sqrt(w * w + paddedH * paddedH)
    local scale      = (paddedDiag / cfg.imageDiag) * (dMin + (math.max(math.abs(pitch), math.abs(roll)) / 90) * (dMax - dMin))

    local drawW, drawH = cfg.iw * scale, cfg.ih * scale
    local cx, cy       = x + w / 2, y + h / 2
    local drawX        = cx - drawW / 2
    local drawY        = cy - drawH / 2 + pitch * ppd

    lcd.drawBitmap(drawX, drawY, img:rotate(roll), drawW, drawH)

    -- Crosshair
    lcd.color(lcd.RGB(255,255,255))
    lcd.drawLine(cx-5, cy, cx+5, cy)
    lcd.drawLine(cx, cy-5, cx, cy+5)
    lcd.drawCircle(cx, cy, 3)

    -- Roll ticks
    local arcR = w * 0.4
    for _, a in ipairs({-60,-45,-30,-20,-10,0,10,20,30,45,60}) do
        local rad = math.rad(a)
        local x1, y1 = cx + arcR * math.sin(rad), y + 10 + arcR * (1 - math.cos(rad))
        local x2, y2 = cx + (arcR-6) * math.sin(rad), y + 10 + (arcR-6) * (1 - math.cos(rad))
        lcd.drawLine(x1,y1,x2,y2)
    end
    lcd.drawFilledTriangle(cx, y+5, cx-6, y+15, cx+6, y+15)

    -- Pitch ladder
    for ang = -90, 90, 10 do
        local off = (pitch - ang) * ppd
        local py = cy + off
        if py > y-40 and py < y+h+40 then
            local major = (ang % 20 == 0)
            local len   = major and 25 or 15
            local x1,y1 = rotate(cx-len, py, cx, cy, roll)
            local x2,y2 = rotate(cx+len, py, cx, cy, roll)
            lcd.drawLine(x1,y1,x2,y2)
            if major then
                local lbl  = tostring(ang)
                local lx,ly = rotate(cx-len-10, py-4, cx, cy, roll)
                local rx,ry = rotate(cx+len+2, py-4, cx, cy, roll)
                lcd.drawText(lx, ly, lbl, RIGHT)
                lcd.drawText(rx, ry, lbl, LEFT)
            end
        end
    end

    -- Compass
    local heading = math.floor((yaw + 360) % 360)
    local compassY = y + h - 24
    local labels = { [0]="N", [45]="NE", [90]="E", [135]="SE", [180]="S", [225]="SW", [270]="W", [315]="NW" }
    for ang = -90, 90, 10 do
        local hdg = (heading + ang + 360) % 360
        local px  = cx + ang * ppd
        if px > x and px < x+w then
            local th = (hdg % 30 == 0) and 8 or 4
            lcd.drawLine(px, compassY, px, compassY-th)
            if hdg % 30 == 0 then lcd.drawText(px, compassY-th-8, labels[hdg] or tostring(hdg), CENTERED+FONT_XS) end
        end
    end
    lcd.drawFilledTriangle(cx, compassY+1, cx-5, compassY-7, cx+5, compassY-7)

    -- Heading box
    local boxW,boxH = 60,14
    local bx, by    = cx - boxW/2, compassY + 6
    if by + boxH < y + h then
        lcd.color(lcd.RGB(0,0,0)) lcd.drawFilledRectangle(bx, by, boxW, boxH)
        lcd.color(lcd.RGB(255,255,255)) lcd.drawRectangle(bx, by, boxW, boxH)
        lcd.drawText(cx, by+1, string.format("%03d° %s", heading, labels[heading - (heading % 45)] or (heading.."°")), CENTERED+FONT_XS)
    end

    lcd.setClipping(0,0, lcd.getWindowSize())

    -- Store last values
    box._last = { pitch = pitch, roll = roll, yaw = yaw }
end

return render
