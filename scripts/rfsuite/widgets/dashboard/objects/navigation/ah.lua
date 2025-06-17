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

-- Initialize default image path
local DEFAULT_IMAGE_PATH = "widgets/dashboard/gfx/navigation/ahorizon.png"

-- Rotate helper: rotates point (px,py) around center (cx,cy) by angle (radians)
local function rotate(px, py, cx, cy, angle)
    local s = math.sin(angle)
    local c = math.cos(angle)
    -- translate to origin
    px = px - cx
    py = py - cy
    -- apply rotation
    local xnew = px * c - py * s
    local ynew = px * s + py * c
    -- translate back
    return xnew + cx, ynew + cy
end

-- Determine if widget needs repaint based on cached values
function render.dirty(box)
    if not box._last then
        return true
    end
    local c = box._cache or {}
    local l = box._last  or {}

    local tolP = getParam(box, "tolPitch") or 0.1
    local tolR = getParam(box, "tolRoll")  or 0.1
    local tolY = getParam(box, "tolYaw")   or 0.1

    if math.abs((c.pitch or 0) - (l.pitch or 0)) > tolP
       or math.abs((c.roll  or 0) - (l.roll  or 0)) > tolR
       or math.abs((c.yaw   or 0) - (l.yaw   or 0)) > tolY
    then
        return true
    end

    return false
end

-- Perform sensor reads and cache values; polls at configured interval
function render.wakeup(box, telemetry)
    -- Configurable wakeup interval
    box._wakeupInterval = getParam(box, "wakeupInterval") or 0.1
    box._lastWakeup     = box._lastWakeup or 0
    local now = rfsuite.clock
    if now - box._lastWakeup < box._wakeupInterval then return end
    box._lastWakeup = now

    -- Lazy-load horizon image once
    if not box._image then
        local path = getParam(box, "imagePath") or DEFAULT_IMAGE_PATH
        box._image = loadImage(path)
    end

    -- Read attitude sensors
    local getSensor = telemetry.getSensor
    local pitch = getSensor("attpitch") or 0
    local roll  = getSensor("attroll")  or 0
    local yaw   = getSensor("attyaw")   or 0

    -- Cache current readings for paint and dirty
    box._cache = {
        pitch = pitch,
        roll  = roll,
        yaw   = yaw,
    }
end

-- Draw the attitude horizon using cached values and configuration
function render.paint(x, y, w, h, box)
    local c   = box._cache or {}
    local img = box._image
    if not img then return end

    -- Configuration overrides
    local ppd      = getParam(box, "pixelsPerDeg") or 2.0
    local dMin     = getParam(box, "dynamicScaleMin") or 1.05
    local dMax     = getParam(box, "dynamicScaleMax") or (dMin + 0.9)

    local pitch = c.pitch or 0
    local roll  = c.roll  or 0
    local yaw   = c.yaw   or 0

    lcd.setClipping(x, y, w, h)

    -- Compute scaled image dimensions
    local iw, ih = img:width(), img:height()
    local maxPitchOffset = ppd * 90
    local paddedH = h + 2 * maxPitchOffset
    local paddedDiag = math.sqrt(w^2 + paddedH^2)
    local imageDiag  = math.sqrt(iw^2 + ih^2)

    -- Dynamic scaling based on attitude extremes
    local maxAngle = math.max(math.abs(pitch), math.abs(roll))
    local scaleFactor = dMin + (maxAngle / 90) * (dMax - dMin)
    local scale = (paddedDiag / imageDiag) * scaleFactor

    local drawW = iw * scale
    local drawH = ih * scale
    local cx = x + w / 2
    local cy = y + h / 2
    local drawX = cx - drawW / 2
    local drawY = cy - drawH / 2 + pitch * ppd

    -- Draw rotated horizon
    lcd.drawBitmap(drawX, drawY, img:rotate(roll), drawW, drawH)

    -- Center crosshair
    lcd.color(lcd.RGB(255,255,255))
    lcd.drawLine(cx-5, cy, cx+5, cy)
    lcd.drawLine(cx, cy-5, cx, cy+5)
    lcd.drawCircle(cx, cy, 3)

    -- Roll arc ticks
    local arcR = w * 0.4
    for _, a in ipairs({-60,-45,-30,-20,-10,0,10,20,30,45,60}) do
        local rad = math.rad(a)
        local x1 = cx + arcR * math.sin(rad)
        local y1 = y + 10 + arcR * (1 - math.cos(rad))
        local x2 = cx + (arcR-6) * math.sin(rad)
        local y2 = y + 10 + (arcR-6) * (1 - math.cos(rad))
        lcd.drawLine(x1,y1,x2,y2)
    end
    lcd.drawFilledTriangle(cx, y+5, cx-6, y+15, cx+6, y+15)

    -- Pitch ladder
    for angle = -90, 90, 10 do
        local offset = (pitch - angle) * ppd
        local py = cy + offset
        if py > y-40 and py < y+h+40 then
            local major = (angle % 20 == 0)
            local len = major and 25 or 15
            local x1,y1 = rotate(cx-len, py, cx, cy, roll)
            local x2,y2 = rotate(cx+len, py, cx, cy, roll)
            lcd.drawLine(x1,y1,x2,y2)
            if major then
                local label = tostring(angle)
                local lx,ly = rotate(cx-len-10, py-4, cx, cy, roll)
                local rx,ry = rotate(cx+len+2, py-4, cx, cy, roll)
                lcd.drawText(lx, ly, label, RIGHT)
                lcd.drawText(rx, ry, label, LEFT)
            end
        end
    end

    -- Compass tape
    local heading = math.floor((yaw + 360) % 360)
    local compassY = y + h - 24
    local centerX = cx
    local labels = { [0]="N", [45]="NE", [90]="E", [135]="SE",
                     [180]="S",[225]="SW",[270]="W",[315]="NW" }
    for angle = -90, 90, 10 do
        local hdg = (heading + angle + 360) % 360
        local px = centerX + angle * ppd
        if px > x and px < x+w then
            local tickH = (hdg % 30 == 0) and 8 or 4
            lcd.drawLine(px, compassY, px, compassY-tickH)
            if hdg % 30 == 0 then
                lcd.drawText(px, compassY-tickH-8,
                             labels[hdg] or tostring(hdg),
                             CENTERED+FONT_XS)
            end
        end
    end
    lcd.drawFilledTriangle(centerX, compassY+1,
                           centerX-5, compassY-7,
                           centerX+5, compassY-7)

    -- Heading box
    local boxW,boxH = 60,14
    local boxX = centerX - boxW/2
    local boxY = compassY + 6
    if boxY + boxH < y + h then
        lcd.color(lcd.RGB(0,0,0))
        lcd.drawFilledRectangle(boxX, boxY, boxW, boxH)
        lcd.color(lcd.RGB(255,255,255))
        lcd.drawRectangle(boxX, boxY, boxW, boxH)
        lcd.drawText(centerX, boxY+1,
                     string.format("%03d° %s", heading,
                     labels[heading - (heading % 45)] or (heading.."°")),
                     CENTERED+FONT_XS)
    end

    lcd.setClipping(0,0, lcd.getWindowSize())

    -- Store last values for next dirty check
    box._last = { pitch = c.pitch, roll = c.roll, yaw = c.yaw }
end

return render
