local render = {}

local baseDir = rfsuite.config.baseDir or "default"
local gaugeObj = assert(rfsuite.compiler.loadfile("SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/gauge.lua"))()

function render.wakeup(box, telemetry)
    local get = telemetry and telemetry.getSensorSource
    local voltageSensor = get and get("voltage")
    local cellCountSensor = get and get("cell_count")
    local consumptionSensor = get and get("consumption")
    local voltage = voltageSensor and voltageSensor:value()
    local cellCount = cellCountSensor and cellCountSensor:value()
    local consumed = consumptionSensor and consumptionSensor:value()

    local transform = rfsuite.widgets.dashboard.utils.getParam(box, "transform")
    if transform then
        if type(transform) == "string" and math[transform] then
            voltage = voltage and math[transform](voltage)
            cellCount = cellCount and math[transform](cellCount)
            consumed = consumed and math[transform](consumed)
        elseif type(transform) == "function" then
            voltage = voltage and transform(voltage)
            cellCount = cellCount and transform(cellCount)
            consumed = consumed and transform(consumed)
        end
    end

    local perCellVoltage = (voltage and cellCount and cellCount > 0) and (voltage / cellCount) or nil

    local line1 = string.format("V: %.1f / C: %.2f", voltage or 0, perCellVoltage or 0)
    local line2 = string.format("Used: %d mAh (%dS)", consumed or 0, cellCount or 0)

    box._cache = {
        line1 = line1,
        line2 = line2,
        textColor = rfsuite.widgets.dashboard.utils.resolveColor(
            rfsuite.widgets.dashboard.utils.getParam(box, "textColor")
        ) or lcd.RGB(255,255,255)
    }
end

function render.paint(x, y, w, h, box, telemetry)
    x, y = rfsuite.widgets.dashboard.utils.applyOffset(x, y, box)

    -- Draw gauge as usual
    gaugeObj.gauge(x, y, w, h, box, telemetry)

    -- Draw the info block using cached values
    local c = box._cache or {}
    local line1 = c.line1 or ""
    local line2 = c.line2 or ""
    local textColor = c.textColor or lcd.RGB(255,255,255)

    lcd.font(FONT_S)
    local textW1, textH1 = lcd.getTextSize(line1)
    local textW2, textH2 = lcd.getTextSize(line2)
    local totalH = textH1 + textH2 + 2

    local infoW = math.floor(w * 0.20)
    local paddingX = 8
    local yStart = y + (h - totalH) / 2
    local infoX = x + w - infoW + paddingX
    local maxRight = x + w - 2

    lcd.color(textColor)
    lcd.drawText(math.min(infoX, maxRight - textW1), yStart, line1)
    lcd.drawText(math.min(infoX, maxRight - textW2), yStart + textH1 + 2, line2)
end

return render
