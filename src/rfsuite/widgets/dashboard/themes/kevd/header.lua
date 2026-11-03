--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local requireModule = package.loaded["rfsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local rfsuite = requireModule("widgets/dashboard/context.lua")
local utils = rfsuite.widgets.dashboard.utils
local themeHeader = requireModule("widgets/dashboard/themes/kevd/header_bridge.lua")

-- Factories keep page-owned boxes/bitmap references out of the module cache.
return function(colorMode, headeropts)
    local oldHeight = headeropts.height + 4
    headeropts.height = headeropts.height == 36 and 50 or 42
    local layout = utils.standardHeaderLayout(headeropts)
    local boxes, lastBatteryType
    local background = colorMode.bgcolor
    local image = themeHeader.getToolbarBackground()
    local imageW = image and image:width() or 0
    local imageH = image and image:height() or 0
    local lastW, lastH, drawW, drawH, drawOffsetX, drawOffsetY

    local function paintPageBackground()
        local w, h = lcd.getWindowSize()
        lcd.color(colorMode.bgcolor)
        lcd.drawFilledRectangle(0, 0, w, h)
    end

    local pageBackground = {
        type = "func", subtype = "func", paint = paintPageBackground,
        x_pct = 0, y_pct = 0, w_pct = 1, h_pct = 1,
        bgcolor = colorMode.bgcolor
    }

    local function paint(x, y, w, h)
        -- The engine rounds the seven-column grid down to whole pixels.
        -- Cover its unused right edge as well as transparent artwork margins.
        w = lcd.getWindowSize() - x
        lcd.color(background)
        lcd.drawFilledRectangle(x, y, w, h)
        if image then
            -- Native theme bitmaps are lazy: dimensions can be zero until
            -- the existing handle has been drawn once. Decode that same
            -- handle, then cover it correctly in this paint call.
            if imageW <= 0 or imageH <= 0 then
                lcd.drawBitmap(x, y, image, w, h)
                imageW, imageH = image:width(), image:height()
            end
            local imageAreaH = h
            if imageW > 0 and imageH > 0 and (lastW ~= w or lastH ~= imageAreaH) then
                -- Ethos fits bitmaps while preserving their aspect ratio.
                -- Scale to cover, then clip: no page-colored side margins,
                -- even when the artwork and page have different backgrounds.
                local scale = math.max(w / imageW, imageAreaH / imageH)
                drawW = math.ceil(imageW * scale)
                drawH = math.ceil(imageH * scale)
                drawOffsetX = math.floor((w - drawW) / 2)
                drawOffsetY = math.floor((imageAreaH - drawH) / 2)
                lastW, lastH = w, imageAreaH
            end
            if drawW then
                lcd.setClipping(x, y, w, imageAreaH)
                lcd.drawBitmap(x + drawOffsetX, y + drawOffsetY, image, drawW, drawH)
                lcd.setClipping()
            end
        end
    end

    local function headerBoxes()
        local general = rfsuite.preferences and rfsuite.preferences.general
        local batteryType = general and general.txbatt_type or 0
        if not boxes or lastBatteryType ~= batteryType then
            boxes = utils.standardHeaderBoxes(i18n, colorMode, headeropts, batteryType)
            -- The full-width artwork replaces the Suite logo in the centre.
            -- Reuse its box and the standard array rather than discarding them.
            local banner = boxes[2]
            banner.col, banner.colspan = 1, 7
            banner.type, banner.subtype = "func", "func"
            banner.bgcolor, banner.paint = background, paint
            boxes[1], boxes[2], boxes[3], boxes[4] = banner, boxes[1], boxes[4], boxes[3]
            for i = 2, #boxes do
                local box = boxes[i]
                box.bgcolor = "transparent"
                box.offsety = -1
            end
            boxes[3].col = 6
            boxes[3].barpaddingbottom = 7 -- Keep RSSI clear of the lower edge.
            boxes[4].col = 7
            boxes[4].gaugepaddingtop = boxes[3].barpaddingtop or 0
            boxes[4].gaugepaddingbottom = boxes[3].barpaddingbottom
            -- Keep the battery near the edge and group RSSI beside it.
            -- Resolve offsets only when rebuilding the cached header boxes.
            local width = lcd.getWindowSize()
            local batteryShift = math.max(0, (boxes[4].gaugepaddingright or headeropts.gaugepaddingright or 0) - 6)
            boxes[4].xoffset = batteryShift
            boxes[3].xoffset = batteryShift + math.floor(math.floor(width / 7) * 0.35)
            lastBatteryType = batteryType
        end
        return boxes
    end

    return layout, headerBoxes, oldHeight, pageBackground
end
