--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local toolbox = {}
local wakeupScheduler
local LCD_W, LCD_H
-- Busy cadence: run toolbox invalidation on RUN_NUM of RUN_DEN ticks while MSP is busy.
-- Lower RUN_NUM to yield more CPU to MSP; set RUN_NUM == RUN_DEN to disable this throttle.
local BUSY_WAKEUP_RUN_NUM = 2
local BUSY_WAKEUP_RUN_DEN = 3

local toolBoxList = {[1] = {object = "armflags", name = "Arming Flags"}, [2] = {object = "bbl", name = "Black Box"}, [3] = {object = "craftname", name = "Craft Name"}, [4] = {object = "governor", name = "Governor"}, [5] = {object = "craftimage", name = "Craft Image"}}

local function generateWidgetList(tbl)
    local widgets = {}
    for i, tool in ipairs(tbl) do table.insert(widgets, {tool.name, i}) end
    return widgets
end

function toolbox.create()

    wakeupScheduler = os.clock()

    return {value = 0, state = {setup = false}, loadedWidget = nil}
end

local function screenError(msg, border, pct, padX, padY)

    if not pct then pct = 0.5 end
    if border == nil then border = true end
    if not padX then padX = 8 end
    if not padY then padY = 4 end

    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL, FONT_XXXXL}

    local maxW, maxH = w * pct, h * pct
    local bestFont, bestW, bestH = FONT_XXS, 0, 0

    for _, font in ipairs(fonts) do
        lcd.font(font)
        local tsizeW, tsizeH = lcd.getTextSize(msg)
        if tsizeW <= maxW and tsizeH <= maxH then
            bestFont = font
            bestW, bestH = tsizeW, tsizeH
        else
            break
        end
    end

    lcd.font(bestFont)

    local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
    lcd.color(textColor)

    local x = (w - bestW) / 2
    local y = (h - bestH) / 2

    if border then lcd.drawRectangle(x - padX, y - padY, bestW + padX * 2, bestH + padY * 2) end

    lcd.drawText(x, y, msg)
end

function toolbox.paint(widget)

    if not rfsuite.session.toolbox then return end

    if not widget.object then return end

    local isCompiledCheck = "@i18n(iscompiledcheck)@"
    if isCompiledCheck ~= "true" and isCompiledCheck ~= "eurt" then
        screenError("i18n not compiled", true, 0.6)
        return
    end

    local msg = rfsuite.session.toolbox[toolBoxList[widget.object].object] or "-"
    local title = toolBoxList[widget.object].name

    local w, h = lcd.getWindowSize()
    local isDarkMode = lcd.darkMode()

    local offsetY = 0

    local TITLE_COLOR = lcd.darkMode() and lcd.RGB(154, 154, 154) or lcd.RGB(77, 73, 77)
    local TEXT_COLOR = lcd.darkMode() and lcd.RGB(255, 255, 255) or lcd.RGB(77, 73, 77)

    if widget.title then
        local fonts = {FONT_XXS, FONT_XS, FONT_S}

        local maxW, maxH = w * 0.9, h
        local bestFont = FONT_XXS
        local bestW, bestH = 0, 0

        for _, font in ipairs(fonts) do
            lcd.font(font)
            local tsizeW, tsizeH = lcd.getTextSize(title)

            if tsizeW <= maxW and tsizeH <= maxH then
                bestFont = font
                bestW, bestH = tsizeW, tsizeH
            else
                break
            end
        end

        lcd.font(bestFont)

        local textColor = isDarkMode and lcd.RGB(255, 255, 255, 1) or lcd.RGB(90, 90, 90)
        lcd.color(textColor)

        local x = (w - bestW) / 2
        local y = bestH / 4
        lcd.color(TITLE_COLOR)
        lcd.drawText(x, y, title)

        offsetY = bestH - 3

    end

    if type(msg) == "string" then

        local fonts = {FONT_XXS, FONT_XS, FONT_S, FONT_STD, FONT_L, FONT_XL, FONT_XXL}

        local maxW, maxH = w * 0.9, h
        local bestFont = FONT_XXS
        local bestW, bestH = 0, 0

        for _, font in ipairs(fonts) do
            lcd.font(font)
            local tsizeW, tsizeH = lcd.getTextSize(msg)

            if tsizeW <= maxW and tsizeH <= maxH then
                bestFont = font
                bestW, bestH = tsizeW, tsizeH
            else
                break
            end
        end

        lcd.font(bestFont)

        local x = (w - bestW) / 2
        local y = (h - bestH) / 2 + offsetY
        lcd.color(TEXT_COLOR)
        lcd.drawText(x, y, msg)
    elseif type(msg) == "function" then
        msg()
    else

        local bitmapPtr = msg
        local bitmapX = 0
        local bitmapY = 0
        local bitmapW = w
        local bitmapH = h

        lcd.drawBitmap(bitmapX, bitmapY + offsetY, bitmapPtr, bitmapW, bitmapH - offsetY)

    end
end

function toolbox.wakeup(widget)

    if not rfsuite.session.toolbox then
        rfsuite.session.toolbox = {}
        return
    end

    local isCompiledCheck = "@i18n(iscompiledcheck1)@"
    if isCompiledCheck ~= "true" and isCompiledCheck ~= "eurt" then
        lcd.invalidate()
        return
    end

    local scheduler = lcd.isVisible() and 0.25 or 5
    local now = os.clock()

    if now - (widget.wakeupScheduler or 0) > scheduler then
        --If MSP is busy, only run UI tasks every N ticks to allow background processing to complete and avoid UI freezes.
        if rfsuite.session and rfsuite.session.mspBusy then
            widget._busyWakeupTick = ((widget._busyWakeupTick or 0) % BUSY_WAKEUP_RUN_DEN) + 1
            if widget._busyWakeupTick > BUSY_WAKEUP_RUN_NUM then
                widget.wakeupScheduler = now
                return
            end
        else
            widget._busyWakeupTick = 0
        end
        lcd.invalidate()
        widget.wakeupScheduler = now
    end

end

function toolbox.menu(widget)
    if widget.state.setup and widget.loadedWidget and type(widget.loadedWidget.menu) == "function" then return widget.loadedWidget.menu(widget) end
    return {}
end

function toolbox.i18n(widget)
    if not widget then return {} end
    if widget.state.setup and widget.loadedWidget and type(widget.loadedWidget.i18n) == "function" then return widget.loadedWidget.i18n(widget) end
    return {}
end

function toolbox.configure(widget)
    local formLines = {}
    local formFields = {}
    local formLineCnt = 0
    local formFieldCount = 0

    formLineCnt = formLineCnt + 1
    formLines[formLineCnt] = form.addLine("Title")
    formFieldCount = formFieldCount + 1
    formFields[formFieldCount] = form.addBooleanField(formLines[formLineCnt], nil, function() return widget.title end, function(newValue)
        if widget.title and widget.title ~= newValue then
            widget.state.setup = false
            widget.loadedWidget = nil
            widget.wakeupSchedulerUI = 0
        end
        widget.title = newValue
    end)

    formLineCnt = formLineCnt + 1
    formLines[formLineCnt] = form.addLine("Widget type")
    formFieldCount = formFieldCount + 1
    formFields[formFieldCount] = form.addChoiceField(formLines[formLineCnt], nil, generateWidgetList(toolBoxList), function()
        if not widget.object then widget.object = 1 end
        return widget.object
    end, function(newValue)
        widget.object = newValue

        widget.state.setup = false
        widget.loadedWidget = nil
    end)
end

function toolbox.read(widget)
    widget.title  = storage.read("title")
    widget.object = storage.read("object")
end


function toolbox.write(widget)
    storage.write("title", widget.title)
    storage.write("object", widget.object)
end

function toolbox.close() rfsuite.session.toolbox = nil end

toolbox.title = false

return toolbox
