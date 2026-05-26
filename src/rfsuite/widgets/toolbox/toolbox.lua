--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local _G = _G

local toolbox = {}
local wakeupScheduler
local LCD_W, LCD_H
-- Busy cadence: run toolbox invalidation on RUN_NUM of RUN_DEN ticks while MSP is busy.
-- Lower RUN_NUM to yield more CPU to MSP; set RUN_NUM == RUN_DEN to disable this throttle.
local BUSY_WAKEUP_RUN_NUM = 2
local BUSY_WAKEUP_RUN_DEN = 3

local toolBoxList = {[1] = {object = "armflags", name = "@i18n(widgets.armflags.name)@"}, [2] = {object = "bbl", name = "@i18n(widgets.bbl.name)@"}, [3] = {object = "craftname", name = "@i18n(widgets.craftname.name)@"}, [4] = {object = "governor", name = "@i18n(widgets.governor.name)@"}, [5] = {object = "craftimage", name = "@i18n(widgets.craftimage.name)@"}, [6] = {object = "timer", name = "@i18n(widgets.dashboard.flight_time)@"}}
local themeColorCache = {usesThemeColors = nil, primary = nil, secondary = nil, colors = nil, legacyDark = nil, legacyColors = nil}

local function rgb(r, g, b, a) return lcd.RGB(r, g, b, a or 1) end

local function isLegacyDarkMode()
    return type(lcd.darkMode) == "function" and lcd.darkMode() == true
end

local function supportsSystemThemeColors()
    return rfsuite
        and rfsuite.utils
        and rfsuite.utils.ethosVersionAtLeast
        and rfsuite.utils.ethosVersionAtLeast({26, 1, 0})
        or false
end

local function resolveThemeConstant(name)
    if not supportsSystemThemeColors() then return nil end
    if type(lcd.themeColor) ~= "function" then return nil end
    local key = _G[name]
    if type(key) ~= "number" then return nil end
    return lcd.themeColor(key)
end

local function getThemeColors()
    local primary = resolveThemeConstant("THEME_PRIMARY_COLOR")
    local secondary = resolveThemeConstant("THEME_SECONDARY_COLOR")

    if type(primary) == "number" or type(secondary) == "number" then
        if themeColorCache.colors == nil
            or themeColorCache.usesThemeColors ~= true
            or themeColorCache.primary ~= primary
            or themeColorCache.secondary ~= secondary then
            themeColorCache.usesThemeColors = true
            themeColorCache.primary = primary
            themeColorCache.secondary = secondary
            themeColorCache.colors = {
                title = secondary or primary or rgb(77, 73, 77),
                text = primary or secondary or rgb(77, 73, 77),
                message = primary or secondary or rgb(90, 90, 90)
            }
        end
        return themeColorCache.colors
    end

    local isDark = isLegacyDarkMode()
    if themeColorCache.legacyColors == nil or themeColorCache.legacyDark ~= isDark then
        themeColorCache.legacyDark = isDark
        themeColorCache.legacyColors = {
            title = isDark and rgb(154, 154, 154) or rgb(77, 73, 77),
            text = isDark and rgb(255, 255, 255) or rgb(77, 73, 77),
            message = isDark and rgb(255, 255, 255) or rgb(90, 90, 90)
        }
    end
    return themeColorCache.legacyColors
end

local function generateWidgetList(tbl)
    local widgets = {}
    for i, tool in ipairs(tbl) do table.insert(widgets, {tool.name, i}) end
    return widgets
end

local function loadWidget(widget)
    if widget.loadedWidget then return end
    local tool = toolBoxList[widget.object]
    if not tool then return end

    local path = "widgets/dashboard/objects/text/" .. tool.object .. ".lua"
    local file = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/" .. path
    local chunk, err = loadfile(file)
    if chunk then
        local status, result = pcall(chunk)
        if status then
            widget.loadedWidget = result
        else
            print("Error executing widget " .. tool.object .. ": " .. tostring(result))
        end
    else
        if err and not string.find(tostring(err), "No such file") then
            print("Error loading widget file " .. file .. ": " .. tostring(err))
        end
    end
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
    local themeColors = getThemeColors()

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

    lcd.color(themeColors.message)

    local x = (w - bestW) / 2
    local y = (h - bestH) / 2

    if border then lcd.drawRectangle(x - padX, y - padY, bestW + padX * 2, bestH + padY * 2) end

    lcd.drawText(x, y, msg)
end

function toolbox.paint(widget)

    if not rfsuite.session.toolbox then return end

    if not widget.object then return end

    if widget.loadedWidget and widget.loadedWidget.paint then
        local w, h = lcd.getWindowSize()
        widget.loadedWidget.paint(0, 0, w, h, widget)
        return
    end

    local isCompiledCheck = "@i18n(iscompiledcheck)@"
    if isCompiledCheck ~= "true" and isCompiledCheck ~= "eurt" then
        screenError("i18n not compiled", true, 0.6)
        return
    end

    local msg = rfsuite.session.toolbox[toolBoxList[widget.object].object] or "-"
    local title = toolBoxList[widget.object].name

    local w, h = lcd.getWindowSize()
    local themeColors = getThemeColors()

    local offsetY = 0

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

        local x = (w - bestW) / 2
        local y = bestH / 4
        lcd.color(themeColors.title)
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
        lcd.color(themeColors.text)
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

    loadWidget(widget)

    if widget.loadedWidget and widget.loadedWidget.wakeup then
        widget.loadedWidget.wakeup(widget)
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

function toolbox.event(widget, category, value, x, y)
    if widget.onpress and category == EVT_TOUCH and value == TOUCH_release then
        widget.onpress()
        return true
    end
    return false
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
    formLines[formLineCnt] = form.addLine("@i18n(widgets.toolbox.configure_title)@")
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
    formLines[formLineCnt] = form.addLine("@i18n(widgets.toolbox.configure_widget_type)@")
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
