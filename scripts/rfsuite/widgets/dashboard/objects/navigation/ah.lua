local render = {}
local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam


-- Rotate point (x, y) around center (cx, cy) by angle in degrees
local function rotate(x, y, cx, cy, angle)
    local rad = math.rad(angle)
    local dx = x - cx
    local dy = y - cy
    local cosA = math.cos(rad)
    local sinA = math.sin(rad)
    return
        cx + dx * cosA - dy * sinA,
        cy + dx * sinA + dy * cosA
end

function render.dirty(box)
    return true
end

function render.wakeup(box, telemetry)
    box._cache = box._cache or {}
    box._cache.pitch = telemetry.getSensor("attpitch") or 0
    box._cache.roll = telemetry.getSensor("attroll") or 0
    box._cache.yaw= telemetry.getSensor("attyaw") or 0

    if not box._cache.horizon then
        box._cache.horizon = rfsuite.utils.loadImage("widgets/dashboard/gfx/navigation/ahorizon.png")
    end
end

function render.paint(x, y, w, h, box)
    local c = box._cache or {}
    local img = c.horizon
    if not img then return end

    local pitch = c.pitch or 0
    local roll = c.roll or 0


    -- Set clipping to the widget bounds BEFORE drawing
    lcd.setClipping(x, y, w, h)

    -- Calculate center and pitch offset
    local imgW, imgH = img:width(), img:height()
    local cx = x + w / 2
    local cy = y + h / 2
    local pitchOffset = pitch * 2.0

    -- Image is rotated around center, and vertically offset by pitch
    local drawX = cx - imgW / 2
    local drawY = cy - imgH / 2 + pitchOffset

    -- Draw rotated image within clipping region
    lcd.drawBitmap(drawX, drawY, img:rotate(roll))

    -- Draw fixed aircraft crosshair
    lcd.color(lcd.RGB(255, 255, 255))
    lcd.drawLine(cx - 5, cy, cx + 5, cy)
    lcd.drawLine(cx, cy - 5, cx, cy + 5)
    lcd.drawCircle(cx, cy, 3)


    -----------------------------------------------------------------
    -- Draw roll arc (static ticks + dynamic pointer)
    -----------------------------------------------------------------
    local arcRadius = w * 0.4
    local tickLength = 6
    local arcAngles = { -60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60 }

    lcd.color(lcd.RGB(255, 255, 255))

    for _, a in ipairs(arcAngles) do
        local rad = math.rad(a)
        local x1 = cx + arcRadius * math.sin(rad)
        local y1 = y + 10 + arcRadius * (1 - math.cos(rad))
        local x2 = cx + (arcRadius - tickLength) * math.sin(rad)
        local y2 = y + 10 + (arcRadius - tickLength) * (1 - math.cos(rad))
        lcd.drawLine(x1, y1, x2, y2)
    end

    -- Current roll pointer (triangle at top center)
    local pointerSize = 6
    lcd.drawFilledTriangle(cx, y + 5, cx - pointerSize, y + 15, cx + pointerSize, y + 15)    

    -----------------------------------------------------------------
    -- Pitch ladder (±90°, every 10°)
    -----------------------------------------------------------------
    local pitchStep = 10
    local pitchRange = 90
    local pixelsPerDeg = 2.0

    for angle = -pitchRange, pitchRange, pitchStep do
        local offset = (pitch - angle) * pixelsPerDeg
        local py = cy + offset

        if py > y - 40 and py < y + h + 40 then
            -- Adjust tick length
            local isMajor = (angle % 20 == 0)
            local len = isMajor and 25 or 15

            -- Rotate endpoints
            local x1, y1 = rotate(cx - len, py, cx, cy, roll)
            local x2, y2 = rotate(cx + len, py, cx, cy, roll)

            lcd.color(lcd.RGB(255, 255, 255))
            lcd.drawLine(x1, y1, x2, y2)

            -- Add side labels for major lines
            if isMajor then
                local label = tostring(angle)
                local lx, ly = rotate(cx - len - 10, py - 4, cx, cy, roll)
                lcd.drawText(lx, ly, label, RIGHT)

                local rx, ry = rotate(cx + len + 2, py - 4, cx, cy, roll)
                lcd.drawText(rx, ry, label, LEFT)
            end
        end
    end

    -----------------------------------------------------------------
    -- Compass heading tape (±90° around yaw)
    -----------------------------------------------------------------
    local yaw = c.yaw or 0
    local headingCenter = math.floor((yaw + 360) % 360)
    local compassY = y + h - 24  -- position higher to avoid clipping
    local centerX = x + w / 2

    -- Label conversion
    local compassLabels = {
        [0] = "N", [45] = "NE", [90] = "E", [135] = "SE",
        [180] = "S", [225] = "SW", [270] = "W", [315] = "NW"
    }

    local pixelsPerDeg = 2.0
    local tapeRange = 90

    lcd.color(lcd.RGB(255, 255, 255))
    for angle = -tapeRange, tapeRange, 10 do
        local hdg = (headingCenter + angle + 360) % 360
        local px = centerX + angle * pixelsPerDeg

        if px > x and px < x + w then
            -- Tick
            local tickH = (hdg % 30 == 0) and 8 or 4
            lcd.drawLine(px, compassY, px, compassY - tickH)

            -- Label
            if hdg % 30 == 0 then
                local label = compassLabels[hdg] or tostring(hdg)
                lcd.drawText(px, compassY - tickH - 8, label, CENTERED + FONT_XS)
            end
        end
    end

    -- Center marker (triangle)
    lcd.drawFilledTriangle(centerX, compassY + 1, centerX - 5, compassY - 7, centerX + 5, compassY - 7)

    -- Boxed current heading
    local headingLabel = compassLabels[headingCenter - (headingCenter % 45)] or (headingCenter .. "°")
    local headingText = string.format("%03d° %s", headingCenter, headingLabel)
    local boxW = 60
    local boxH = 14
    local boxX = centerX - boxW / 2
    local boxY = compassY + 6  -- now guaranteed to be inside clipping

    -- Ensure it fits inside widget
    if boxY + boxH < y + h then
        lcd.color(lcd.RGB(0, 0, 0))
        lcd.drawFilledRectangle(boxX, boxY, boxW, boxH)

        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawRectangle(boxX, boxY, boxW, boxH)
        lcd.drawText(centerX, boxY + 1, headingText, CENTERED + FONT_XS)
    end
 


    ----------------------------------------
    -- Reset clipping to full screen
    ----------------------------------------
    widgetWidth,widgetHeight = lcd.getWindowSize()	
    lcd.setClipping(0, 0, widgetWidth, widgetHeight)
    
end

return render
