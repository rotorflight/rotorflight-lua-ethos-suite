--[[
  Toolbar helper for dashboard
]] --

local DEFAULT_TOOLBAR_ITEMS = {
    {
        name = "@i18n(widgets.dashboard.reset_flight)@",
        order = 100,
        icon = "widgets/dashboard/gfx/toolbar_reset.png",
        iconSize = 55,
        onClick = function(dashboard)
            dashboard.resetFlightModeAsk()
        end
    },
    {
        name = "@i18n(widgets.bbl.erase_dataflash)@",
        order = 110,
        icon = "widgets/dashboard/gfx/toolbar_erase.png",
        iconSize = 55,
        onClick = function(dashboard)
            dashboard.eraseBlackboxAsk()
        end
    }
}

local M = {}

local toolbarMaskCache = {}

local function loadToolbarMask(path, lcd)
    if not path or not lcd or not lcd.loadMask then return nil end
    local mask = toolbarMaskCache[path]
    if not mask then
        mask = lcd.loadMask(path, true)
        toolbarMaskCache[path] = mask
    end
    return mask
end

local function getToolbarBounds(dashboard, lcd)
    local W, H = lcd.getWindowSize()
    local barH = math.floor(H * 0.4)
    local bounds = dashboard._layoutBounds
    local x = 0
    local w = W
    local y = H - barH
    if bounds and bounds.w and bounds.h then
        x = bounds.x
        w = bounds.w
        y = bounds.y + bounds.h - barH
    end
    if w < 1 or y < 0 then return end
    return x, y, w, barH
end


local function getToolbarItems(dashboard)
    if type(dashboard.toolbarItems) == "table" then
        return dashboard.toolbarItems
    end
    return DEFAULT_TOOLBAR_ITEMS
end

function M.getItems(dashboard)
    local items = getToolbarItems(dashboard)
    if type(items) ~= "table" then return {} end
    return items
end

local function fitLabelToWidth(lcd, label, maxW)
    if not label or label == "" then return label end
    local tw = lcd.getTextSize(label)
    if tw <= maxW then return label end
    local ellipsis = "..."
    local ellW = lcd.getTextSize(ellipsis)
    if ellW >= maxW then return ellipsis end
    local trimmed = label
    while #trimmed > 1 do
        trimmed = trimmed:sub(1, #trimmed - 1)
        local w = lcd.getTextSize(trimmed)
        if w + ellW <= maxW then
            return trimmed .. ellipsis
        end
    end
    return ellipsis
end

local function getToolbarCache(dashboard)
    dashboard._toolbarCache = dashboard._toolbarCache or {}
    return dashboard._toolbarCache
end

function M.draw(dashboard, rfsuite, lcd, sort, max, FONT_XS, CENTERED, THEME_DEFAULT_COLOR, THEME_DEFAULT_BGCOLOR, THEME_FOCUS_COLOR, THEME_FOCUS_BGCOLOR)
    if not dashboard.toolbarVisible then return end
    local x, y, w, barH = getToolbarBounds(dashboard, lcd)
    if not x then return end

    local themeDefault = lcd.themeColor(THEME_DEFAULT_COLOR)
    local themeFocus = lcd.themeColor(THEME_FOCUS_COLOR)
    local themeDefaultBg = lcd.themeColor(THEME_DEFAULT_BGCOLOR)
    local themeFocusBg = lcd.themeColor(THEME_FOCUS_BGCOLOR)
    local lineColor = themeFocus
    local isDark = lcd.darkMode()
    if isDark then
        lcd.color(lcd.RGB(0, 0, 0, 0.95))
    else
        lcd.color(lcd.RGB(255, 255, 255, 0.95))
    end
    lcd.drawFilledRectangle(x, y, w, barH)
    lcd.color(lineColor)
    lcd.drawFilledRectangle(x, y, w, 4)

    local items = getToolbarItems(dashboard)
    if #items == 0 then return end

    local cache = getToolbarCache(dashboard)
    local slots = 6
    local recache = (cache.itemsRef ~= items) or (cache.w ~= w) or (cache.h ~= barH) or (cache.font ~= FONT_XS) or (cache.slots ~= slots)
    if recache then
        local sorted = {}
        for i = 1, #items do sorted[i] = items[i] end
        sort(sorted, function(a, b) return (a.order or 0) < (b.order or 0) end)
        cache.itemsRef = items
        cache.sortedItems = sorted
        cache.w = w
        cache.h = barH
        cache.font = FONT_XS
        cache.slots = slots
        cache.labels = {}
    end
    local itemW = w / slots
    local boxFill = themeFocusBg
    local selectedFill = themeFocus
    local rects = {}
    local visibleItems = {}
    local iconSize = 55
    local textPadTop = 6
    local slotPad = 12
    local groupPadTop = 6
    local iconPad = 6
    lcd.font(FONT_XS)
    for i = 1, slots do
        local item = (cache.sortedItems and cache.sortedItems[i]) or items[i]
        if item then
            local ix = x + (i - 1) * itemW
            local iw = itemW
            local bx = ix + slotPad
            local by = y + slotPad + groupPadTop
            local bw = iw - (slotPad * 2)
            local bh = barH - (slotPad * 2) - groupPadTop
            rects[#rects + 1] = {x = ix, y = y, w = iw, h = barH, item = item}
            visibleItems[#visibleItems + 1] = item
            local isSelected = (dashboard.selectedToolbarIndex == i)
            if isSelected then
                lcd.color(selectedFill)
            else
                lcd.color(boxFill)
            end
            lcd.drawFilledRectangle(bx, by, bw, bh)
            if item.icon then
                local sz = item.iconSize or iconSize
                local tw = 0
                local th = 0
                local fitLabel = nil
                if item.name then
                    fitLabel = cache.labels and cache.labels[i]
                    if not fitLabel then
                        fitLabel = fitLabelToWidth(lcd, item.name, bw - 6)
                        if cache.labels then cache.labels[i] = fitLabel end
                    end
                    tw, th = lcd.getTextSize(fitLabel)
                end
                local textY = by + textPadTop
                if item.name then
                    lcd.color(isSelected and themeDefaultBg or themeDefault)
                    lcd.drawText(bx + (bw * 0.5), textY, fitLabel, CENTERED)
                end
                local labelBand = th + (textPadTop * 2)
                local maxIconW = bw - (iconPad * 2)
                local maxIconH = bh - labelBand - iconPad
                if sz > maxIconW then sz = maxIconW end
                if sz > maxIconH then sz = maxIconH end
                local iconTop = by + labelBand
                local iconY = iconTop + max(0, (bh - labelBand - sz) * 0.5)
                local iconX = bx + (bw - sz) * 0.5
                iconX = math.floor(iconX + 0.5)
                iconY = math.floor(iconY + 0.5)
                local mask = loadToolbarMask(item.icon, lcd)
                if mask then
                    lcd.color(isSelected and themeDefaultBg or themeDefault)
                    lcd.drawMask(iconX, iconY, mask)
                end
            end
        end
    end
    dashboard._toolbarRects = rects
    dashboard._toolbarItemsSorted = visibleItems
end

function M.handleEvent(dashboard, widget, category, value, x, y, lcd)
    if not dashboard.toolbarVisible then return false end

    if category == EVT_KEY and lcd.hasFocus() then
        local rects = dashboard._toolbarRects or {}
        local count = #rects
        if count > 0 then
            local idx = dashboard.selectedToolbarIndex or 1
            if value == 4099 then
                idx = idx - 1
                if idx < 1 then idx = count end
                dashboard.selectedToolbarIndex = idx
                lcd.invalidate(widget)
                return true
            elseif value == 4100 then
                idx = idx + 1
                if idx > count then idx = 1 end
                dashboard.selectedToolbarIndex = idx
                lcd.invalidate(widget)
                return true
            elseif value == 33 then
                local r = rects[idx]
                if r and r.item and type(r.item.onClick) == "function" then
                    r.item.onClick(dashboard)
                    return true
                end
            elseif value == 35 then
                dashboard.selectedToolbarIndex = nil
                lcd.invalidate(widget)
                return true
            end
        end
    end

    if category == 1 and (value == 16641 or value == 16640) and x and y then
        local rects = dashboard._toolbarRects or {}
        for idx, r in ipairs(rects) do
            if x >= r.x and x < (r.x + r.w) and y >= r.y and y < (r.y + r.h) then
                dashboard.selectedToolbarIndex = idx
                lcd.invalidate(widget)
                if r.item and type(r.item.onClick) == "function" then
                    r.item.onClick(dashboard)
                    return true
                end
            end
        end
    end

    return false
end

return M
