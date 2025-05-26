local render = {}


rfsuite.session.dialImageCache = {}
local rotatedPointerCache = {}
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

local function loadDialAssets(panelPath, pointerPath)
    local key = (panelPath or "") .. ":" .. (pointerPath or "")
    if not rfsuite.session.dialImageCache[key] then
        rfsuite.session.dialImageCache[key] = {
            panel = rfsuite.utils.loadImage(panelPath),
            pointer = rfsuite.utils.loadImage(pointerPath)
        }
    end
    return rfsuite.session.dialImageCache[key].panel, rfsuite.session.dialImageCache[key].pointer
end

local function calDialAngle(percent)
    local angle = 315 + percent * 270 / 100
    while angle > 360 do angle = angle - 360 end
    return angle
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

function render.dial(x, y, w, h, box, telemetry)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    -- Draw box background (support bgColor)
    local bgColor = rfsuite.widgets.dashboard.utils.resolveColor(rfsuite.widgets.dashboard.utils.getParam(box, "bgcolor")) or (lcd.darkMode() and lcd.RGB(40, 40, 40) or lcd.RGB(240, 240, 240))
    lcd.color(bgColor)
    lcd.drawFilledRectangle(x, y, w, h)

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

    -- New flexible dial/pointer asset logic:
    local dial = rfsuite.widgets.dashboard.utils.getParam(box, "dial")
    local pointer = rfsuite.widgets.dashboard.utils.getParam(box, "pointer")
    local panelPath = resolveDialAsset(dial, "widgets/dashboard/gfx/dials") or "widgets/dashboard/gfx/panel1.png"
    local pointerPath = resolveDialAsset(pointer, "widgets/dashboard/gfx/pointers") or "widgets/dashboard/gfx/pointer1.png"

    local panelImg, pointerImg = loadDialAssets(panelPath, pointerPath)
    if panelImg and pointerImg then
        local drawX, drawY, drawW, drawH = computeDrawArea(panelImg, x, y, w, h, aspect, align)
        lcd.drawBitmap(drawX, drawY, panelImg, drawW, drawH)

        local angle = calDialAngle(percent)
        local boxId = tostring(box)
        local rotatedKey = (panelPath or "") .. ":" .. (pointerPath or "") .. ":" .. angle

        if lastRotatedKey[boxId] ~= rotatedKey then
            if not rotatedPointerCache[rotatedKey] then
                rotatedPointerCache[rotatedKey] = pointerImg:rotate(angle)
            end
            lastRotatedKey[boxId] = rotatedKey
        end

        local rotated = rotatedPointerCache[rotatedKey]
        if rotated then
            lcd.drawBitmap(drawX, drawY, rotated, drawW, drawH)
        end
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