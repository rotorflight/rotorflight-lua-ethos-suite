local render = {}


rfsuite.session.dialImageCache = {}
local lastDialValue = {}
local lastRotatedKey = {}



-- New helper: resolves dial or pointer value to an image path
local function resolveDialAsset(value, basePath)
    if type(value) == "function" then
        value = value()
    end
    if type(value) == "number" then
        return string.format("%s/%d.png", basePath, value)
    elseif type(value) == "string" then
        if value:match("^%d+$") then
            -- If it's a numeric string, treat as number (for backward compat)
            return string.format("%s/%s.png", basePath, value)
        else
            return value
        end
    end
    return nil
end

local function loadDialPanelCached(dialId)
    local key = tostring(dialId)
    if not rfsuite.session.dialImageCache[key] then
        local panelPath = resolveDialAsset(dialId, "widgets/dashboard/gfx/dials") or "widgets/dashboard/gfx/dials/panel1.png"
        rfsuite.session.dialImageCache[key] = rfsuite.utils.loadImage(panelPath)
    end
    return rfsuite.session.dialImageCache[key]
end

-- Calculate angle
local function calDialAngle(percent, startAngle, sweepAngle)
    return (startAngle or 315) + (sweepAngle or 270) * (percent or 0) / 100
end

-- Draw bar-style needle using two triangles (Ethos only!)
local function drawBarNeedle(cx, cy, length, thickness, angleDeg, color)
    
    local angleRad = math.rad(angleDeg)
    local cosA = math.cos(angleRad)
    local sinA = math.sin(angleRad)

    -- Tip position
    local tipX = cx + cosA * length
    local tipY = cy + sinA * length

    -- Perpendicular for thickness
    local perpA = angleRad + math.pi / 2
    local dx = math.cos(perpA) * (thickness / 2)
    local dy = math.sin(perpA) * (thickness / 2)

    -- Four corners of the bar
    local base1X = cx + dx
    local base1Y = cy + dy
    local base2X = cx - dx
    local base2Y = cy - dy
    local tip1X = tipX + dx
    local tip1Y = tipY + dy
    local tip2X = tipX - dx
    local tip2Y = tipY - dy

    -- Main bar as two triangles
    lcd.color(color)
    lcd.drawFilledTriangle(base1X, base1Y, tip1X, tip1Y, tip2X, tip2Y)
    lcd.drawFilledTriangle(base1X, base1Y, tip2X, tip2Y, base2X, base2Y)
    lcd.drawLine(cx, cy, tipX, tipY)
end



local function computeDrawArea(img, x, y, w, h, aspect, align)
    local iw, ih = img:width(), img:height()
    local drawW, drawH = w, h

    if aspect == "fit" then
        local scale = math.min(w / iw, h / ih)
        drawW = iw * scale
        drawH = ih * scale
    elseif aspect == "fill" then
        local scale = math.max(w / iw, h / ih)
        drawW = iw * scale
        drawH = ih * scale
    elseif not aspect or aspect == "original" then
        drawW = iw
        drawH = ih
    end

    local drawX, drawY = x, y
    align = align or "center"
    if align:find("right") then
        drawX = x + w - drawW
    elseif align:find("center") or not align:find("left") then
        drawX = x + (w - drawW) / 2
    end
    if align:find("bottom") then
        drawY = y + h - drawH
    elseif align:find("center") or not align:find("top") then
        drawY = y + (h - drawH) / 2
    end

    return drawX, drawY, drawW, drawH
end

local function calcSweep(startAngle, endAngle)
    -- returns sweep needed to get from start to end, going the shortest direction (clockwise positive)
    local sweep = (endAngle - startAngle)
    -- Optional: Normalize sweep to be between 0 and 360
    if sweep < 0 then sweep = sweep + 360 end
    return sweep
end

function render.dial(x, y, w, h, box, telemetry)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    -- Draw box background
    local bgColor = rfsuite.widgets.dashboard.utils.resolveColor(
        rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")
    ) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

    -- Telemetry/Value
    local value = nil
    local source = rfsuite.widgets.dashboard.utils.getParam(box, "source")
    if source then
        local sensor = telemetry and telemetry.getSensorSource(source)
        value = sensor and sensor:value()
        local transform = rfsuite.widgets.dashboard.utils.getParam(box, "transform")
        if type(transform) == "string" and math[transform] then
            value = value and math[transform](value)
        elseif type(transform) == "function" then
            value = value and transform(value)
        elseif type(transform) == "number" then
            value = value and transform(value)
        end
    end

    local displayValue = value or rfsuite.widgets.dashboard.utils.getParam(box, "novalue") or "-"
    local unit = rfsuite.widgets.dashboard.utils.getParam(box, "unit")
    local min = rfsuite.widgets.dashboard.utils.getParam(box, "min") or 0
    local max = rfsuite.widgets.dashboard.utils.getParam(box, "max") or 100
    local percent = 0
    if value and max ~= min then
        percent = ((value - min) / (max - min)) * 100
        percent = math.max(0, math.min(100, percent))
    end

    local aspect = rfsuite.widgets.dashboard.utils.getParam(box, "aspect")
    local align = rfsuite.widgets.dashboard.utils.getParam(box, "align") or "center"

    -- Panel image logic
    local dialId = rfsuite.widgets.dashboard.utils.getParam(box, "dial")
    local panelImg = loadDialPanelCached(dialId)
    local drawX, drawY, drawW, drawH

    if panelImg then
        drawX, drawY, drawW, drawH = computeDrawArea(panelImg, x, y, w, h, aspect, align)
        lcd.drawBitmap(drawX, drawY, panelImg, drawW, drawH)
    else
        drawX, drawY, drawW, drawH = x, y, w, h
    end

        -- Needle/hub parameters
    if value ~= nil then
        local needleColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "needlecolor")) or lcd.RGB(255, 0, 0)
        local hubColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "needlehubcolor")) or lcd.RGB(0, 0, 0)
        local needleThickness = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "needlethickness")) or 3
        local hubRadius = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "needlehubsize")) or (math.max(2, needleThickness + 2))

        -- Needle angles (support both sweep and endangle, but endangle is preferred)
        local needleStartAngle = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "needlestartangle")) or 135
        local needleEndAngle = rfsuite.widgets.dashboard.utils.getParam(box, "needleendangle")
        if needleEndAngle then
            needleEndAngle = tonumber(needleEndAngle)
        end
        local sweep
        if needleEndAngle then
            sweep = (needleEndAngle - needleStartAngle)
            if math.abs(sweep) > 180 then
                if sweep > 0 then
                    sweep = sweep - 360
                else
                    sweep = sweep + 360
                end
            end
            -- Allow negative sweeps for clockwise dials
            -- If you want always shortest arc, use: if sweep < 0 then sweep = sweep + 360 end
        else
            sweep = tonumber(rfsuite.widgets.dashboard.utils.getParam(box, "needlesweepangle")) or 270
        end

        local angle = calDialAngle(percent, needleStartAngle, sweep)

        -- Find actual dial center/size
        local cx = drawX + drawW / 2
        local cy = drawY + drawH / 2
        local radius = math.min(drawW, drawH) * 0.40
        local needleLength = radius - 6

        if percent and type(percent) == "number" and not (percent ~= percent) then
            drawBarNeedle(cx, cy, needleLength, needleThickness, angle, needleColor)
        end

        lcd.color(hubColor)
        lcd.drawFilledCircle(cx, cy, hubRadius)
    end
    -- Optional title and value
    local title = rfsuite.widgets.dashboard.utils.getParam(box, "title")
    if title then
        lcd.font(FONT_XS)
        local tW, tH = lcd.getTextSize(title)
        tW = tW or 0
        tH = tH or 0
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - tW) / 2, y + h - tH, title)
    end

    if displayValue ~= nil then
        lcd.font(FONT_STD)
        local str = tostring(displayValue or "") .. (unit or "")
        if str == "" then str = "-" end
        local vW, vH = lcd.getTextSize(str)
        vW = vW or 0
        vH = vH or 0
        lcd.color(lcd.RGB(255, 255, 255))
        lcd.drawText(x + (w - vW) / 2, y + h - vH - 16, str)
    end
end




return render