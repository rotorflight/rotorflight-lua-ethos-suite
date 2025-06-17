local render = {}
local utils = rfsuite.widgets.dashboard.utils
local getParam = utils.getParam

function render.dirty(box)
    return true
end

function render.wakeup(box, telemetry)
    local pitch = telemetry.getSensor("attpitch") or 0
    local roll = telemetry.getSensor("attroll") or 0

    box._cache = {
        pitch = pitch,
        roll = roll,
    }
end

-- Rotate point (x, y) around (cx, cy) by angle (degrees)
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

function render.paint(x, y, w, h, box)
    local c = box._cache or {}
    local pitch = c.pitch or 0
    local roll = c.roll or 0

    local cx = x + w / 2
    local cy = y + h / 2
    local pitchOffset = pitch * 2.0  -- scale degrees to pixels

    local sky = lcd.RGB(135, 206, 235)
    local ground = lcd.RGB(139, 69, 19)
    local line = lcd.RGB(255, 255, 255)

    lcd.setClipping(x, y, w, h)

    local pad = 80
    local halfWidth = (w + pad * 2) / 2
    local horizonY = cy + pitchOffset  -- shift band center

    -- Top and bottom edges of the "horizon band"
    local topLx, topLy = rotate(cx - halfWidth, horizonY - 1, cx, horizonY, roll)
    local topRx, topRy = rotate(cx + halfWidth, horizonY - 1, cx, horizonY, roll)
    local botLx, botLy = rotate(cx - halfWidth, horizonY + 1, cx, horizonY, roll)
    local botRx, botRy = rotate(cx + halfWidth, horizonY + 1, cx, horizonY, roll)

    -- Sky (above horizon)
    lcd.color(sky)
    lcd.drawFilledTriangle(x - pad, y - pad, topLx, topLy, topRx, topRy)
    lcd.drawFilledTriangle(x - pad, y - pad, topRx, topRy, x + w + pad, y - pad)

    -- Ground (below horizon)
    lcd.color(ground)
    lcd.drawFilledTriangle(x - pad, y + h + pad, botLx, botLy, botRx, botRy)
    lcd.drawFilledTriangle(x - pad, y + h + pad, botRx, botRy, x + w + pad, y + h + pad)

    -- Horizon line
    lcd.color(line)
    local len = w * 0.3
    local xL, yL = rotate(cx - len, horizonY, cx, horizonY, roll)
    local xR, yR = rotate(cx + len, horizonY, cx, horizonY, roll)
    lcd.drawLine(xL, yL, xR, yR)

    -- Aircraft fixed marker
    lcd.drawLine(cx - 5, cy, cx + 5, cy)
    lcd.drawLine(cx, cy - 5, cx, cy + 5)
    lcd.drawCircle(cx, cy, 3)
end


return render
