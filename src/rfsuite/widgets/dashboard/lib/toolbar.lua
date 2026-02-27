--[[
  Toolbar helper for dashboard
]] --

-- Toolbar item parameters:
-- name (string): label text (i18n supported)
-- order (number): sort order (ascending)
-- icon (string): mask path (PNG/BMP/JPG)
-- iconSize (number): desired mask size in pixels
-- onClick (function(dashboard)): click handler
-- isConnected (boolean): require session connected
-- postConnectComplete (boolean): require postconnect completed
-- apiVersion (table): API version tuple, e.g. {12, 0, 9}
-- apiVersionOp (string): comparison op, e.g. ">=", "<=", "=="
-- enableFunction (function(dashboard, rfsuite)): custom enable check
-- isArmed (boolean): require armed/disarmed state
-- flightModes (table): allowed modes, e.g. {"preflight","inflight"}
    
local DEFAULT_TOOLBAR_ITEMS = {
    {
        name = "Setup",
        order = 5000,
        icon = "widgets/dashboard/gfx/toolbar_app.png",
        iconSize = 55,
        postConnectComplete = true,
        enableFunction = function(dashboard, rfsuite)
            if rfsuite.sysIndex['app'] and system.openPage ~= nil then
                return true
            end
            return false
        end,
        onClick = function(dashboard)
            local actions = dashboard.toolbar_actions
            if actions and type(actions.launchApp) == "function" then
                actions.launchApp()
            end
        end
    },      
    {
        name = "@i18n(widgets.dashboard.reset_flight)@",
        order = 100,
        icon = "widgets/dashboard/gfx/toolbar_reset.png",
        iconSize = 55,
        onClick = function(dashboard)
            local actions = dashboard.toolbar_actions
            if actions and type(actions.resetFlightModeAsk) == "function" then
                actions.resetFlightModeAsk()
            end
        end
    },
    {
        name = "@i18n(widgets.bbl.erase_dataflash)@",
        order = 110,
        icon = "widgets/dashboard/gfx/toolbar_erase.png",
        iconSize = 55,
        isConnected = true,
        onClick = function(dashboard)
            local actions = dashboard.toolbar_actions
            if actions and type(actions.eraseBlackboxAsk) == "function" then
                actions.eraseBlackboxAsk()
            end
        end
    }  
}

local M = {}

local toolbarMaskCache = {}

local function clearToolbarMaskCache(dashboard)
    for k in pairs(toolbarMaskCache) do toolbarMaskCache[k] = nil end
    if dashboard then dashboard._toolbarCache = nil end
end

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

local function isItemEnabled(item, dashboard, rfsuite)
    if not item then return false end
    if type(item.enableFunction) == "function" then
        return item.enableFunction(dashboard, rfsuite) == true
    end
    if item.isConnected == true then
        local sess = rfsuite and rfsuite.session
        if not (sess and sess.isConnected) then return false end
    end
    if item.postConnectComplete == true then
        local sess = rfsuite and rfsuite.session
        if not (sess and sess.postConnectComplete) then return false end
    end
    if item.apiVersion and rfsuite and rfsuite.utils and rfsuite.utils.apiVersionCompare then
        local op = item.apiVersionOp or ">="
        if not rfsuite.utils.apiVersionCompare(op, item.apiVersion) then return false end
    end
    if item.isArmed ~= nil then
        local sess = rfsuite and rfsuite.session
        if not sess then return false end
        if (sess.isArmed == true) ~= (item.isArmed == true) then return false end
    end
    if item.flightModes and type(item.flightModes) == "table" then
        local mode = dashboard and dashboard.flightmode or nil
        local ok = false
        for i = 1, #item.flightModes do
            if item.flightModes[i] == mode then ok = true break end
        end
        if not ok then return false end
    end
    return true
end

function M.draw(dashboard, rfsuite, lcd, sort, max, FONT_XS, CENTERED, THEME_DEFAULT_COLOR, THEME_DEFAULT_BGCOLOR, THEME_FOCUS_COLOR, THEME_FOCUS_BGCOLOR)
    if not dashboard.toolbarVisible then
        clearToolbarMaskCache(dashboard)
        return
    end
    local x, y, w, barH = getToolbarBounds(dashboard, lcd)
    if not x then
        clearToolbarMaskCache(dashboard)
        return
    end

    local themeDefault = lcd.themeColor(THEME_DEFAULT_COLOR)
    local themeFocus = lcd.themeColor(THEME_FOCUS_COLOR)
    local themeDefaultBg = lcd.themeColor(THEME_DEFAULT_BGCOLOR)
    local themeFocusBg = lcd.themeColor(THEME_FOCUS_BGCOLOR)
    local lineColor = themeFocus
    local isDark = lcd.darkMode()
    if isDark then
        lcd.color(lcd.RGB(0, 0, 0, 0.99))
    else
        lcd.color(lcd.RGB(255, 255, 255, 0.99))
    end
    lcd.drawFilledRectangle(x, y, w, barH)
    lcd.color(lineColor)
    lcd.drawFilledRectangle(x, y, w, 4)

    local items = getToolbarItems(dashboard)
    if #items == 0 then
        clearToolbarMaskCache(dashboard)
        return
    end

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
    local enabledItems = {}
    local visibleIcons = {}
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
            local isEnabled = isItemEnabled(item, dashboard, rfsuite)
            enabledItems[i] = isEnabled
            local isSelected = (dashboard.selectedToolbarIndex == i)
            if isEnabled then
                if isSelected then
                    lcd.color(selectedFill)
                else
                    lcd.color(boxFill)
                end
                lcd.drawFilledRectangle(bx, by, bw, bh)
            else
                lcd.color(boxFill)
                lcd.drawRectangle(bx, by, bw, bh, 2)
            end
            if item.icon then
                visibleIcons[item.icon] = true
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
                    if isEnabled then
                        lcd.color(isSelected and themeDefaultBg or themeDefault)
                    else
                        lcd.color(themeDefault)
                    end
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
                    if isEnabled then
                        lcd.color(isSelected and themeDefaultBg or themeDefault)
                    else
                        lcd.color(themeDefault)
                    end
                    lcd.drawMask(iconX, iconY, mask)
                end
            end
            if not isEnabled then
                -- Dim disabled item (drawn after icon/text, within border)
                lcd.color(lcd.RGB(0, 0, 0, 0.8))
                lcd.drawFilledRectangle(bx + 2, by + 2, bw - 4, bh - 4)
            end
        end
    end
    dashboard._toolbarRects = rects
    dashboard._toolbarItemsSorted = visibleItems
    dashboard._toolbarEnabled = enabledItems

    for path in pairs(toolbarMaskCache) do
        if not visibleIcons[path] then
            toolbarMaskCache[path] = nil
        end
    end
end

function M.isItemEnabled(item, dashboard, rfsuite)
    return isItemEnabled(item, dashboard, rfsuite)
end

function M.handleEvent(dashboard, widget, category, value, x, y, lcd)
    if not dashboard.toolbarVisible then return false end

    if category == EVT_KEY and lcd.hasFocus() then
        local rects = dashboard._toolbarRects or {}
        local enabled = dashboard._toolbarEnabled or {}
        local count = #rects
        if count > 0 then
            local idx = dashboard.selectedToolbarIndex or 1
            if value == ROTARY_LEFT then
                local start = idx
                repeat
                    idx = idx - 1
                    if idx < 1 then idx = count end
                until idx == start or enabled[idx] ~= false
                dashboard.selectedToolbarIndex = idx
                dashboard._toolbarLastActive = os.clock()
                lcd.invalidate(widget)
                return true
            elseif value == KEY_ROTARY_RIGHT then
                local start = idx
                repeat
                    idx = idx + 1
                    if idx > count then idx = 1 end
                until idx == start or enabled[idx] ~= false
                dashboard.selectedToolbarIndex = idx
                dashboard._toolbarLastActive = os.clock()
                lcd.invalidate(widget)
                return true
            elseif value == KEY_ENTER_BREAK then
                local r = rects[idx]
                if r and r.item and type(r.item.onClick) == "function" and enabled[idx] ~= false then
                    r.item.onClick(dashboard)
                    dashboard._toolbarLastActive = os.clock()
                    dashboard._toolbarCloseAt = os.clock() + 2
                    return true
                end
            elseif value == KEY_DOWN_BREAK then
                dashboard.selectedToolbarIndex = nil
                dashboard._toolbarLastActive = os.clock()
                dashboard.toolbarVisible = false
                dashboard._toolbarCloseAt = 0
                clearToolbarMaskCache(dashboard)
                lcd.invalidate(widget)
                return true
            end
        end
    end

    if category == EVT_TOUCH and (value == TOUCH_END or value == TOUCH_START) and x and y then
        local rects = dashboard._toolbarRects or {}
        local enabled = dashboard._toolbarEnabled or {}
        for idx, r in ipairs(rects) do
            if x >= r.x and x < (r.x + r.w) and y >= r.y and y < (r.y + r.h) then
                dashboard.selectedToolbarIndex = idx
                dashboard._toolbarLastActive = os.clock()
                lcd.invalidate(widget)
                if r.item and type(r.item.onClick) == "function" and enabled[idx] ~= false then
                    r.item.onClick(dashboard)
                    dashboard._toolbarLastActive = os.clock()
                    dashboard._toolbarCloseAt = os.clock() + 2
                    return true
                end
            end
        end
    end

    return false
end

return M
