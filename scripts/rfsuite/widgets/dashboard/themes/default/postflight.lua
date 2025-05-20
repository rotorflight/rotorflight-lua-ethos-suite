--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] --

local preflight = {}


-- Create function
function preflight.create(widget)

end

-- Paint function
function preflight.paint(widget)
    local WIDGET_W, WIDGET_H = lcd.getWindowSize()
    local telemetry = rfsuite.tasks.telemetry
    local utils = rfsuite.widgets.dashboard.utils

    -- Layout config
    local COLS = 3
    local ROWS = 2
    local PADDING = 4  -- Used for spacing between boxes and top/bottom margin

    -- Calculate drawable area
    local contentWidth = WIDGET_W - ((COLS - 1) * PADDING)
    local contentHeight = WIDGET_H - ((ROWS + 1) * PADDING)  -- rows+1 vertical paddings

    local boxWidth = math.floor(contentWidth / COLS)
    local boxHeight = math.floor(contentHeight / ROWS)

    -- Background
    utils.setBackgroundColourBasedOnTheme()

    -- Positioning helper
    local function getBoxPosition(col, row)
        local x = (col - 1) * (boxWidth + PADDING)
        local y = PADDING + (row - 1) * (boxHeight + PADDING)
        return x, y
    end

    -- Box layout definitions
    local boxes = {
        {col=1, row=1, key="voltage", title="VOLTAGE", unit="V", color=nil},
        {col=2, row=1, key="current", title="CURRENT", unit="A", color=2},
        {col=3, row=1, key="rpm", title="RPM", unit="RPM", color=3, format=math.floor},
        {col=1, row=2, colspan=3, key=nil, title="", value="PRE-FLIGHT", unit="", color=0}
    }

    -- Draw boxes
    for _, box in ipairs(boxes) do
        local x, y = getBoxPosition(box.col, box.row)
        local w = box.colspan and (boxWidth * box.colspan + PADDING * (box.colspan - 1)) or boxWidth
        local h = boxHeight

        local value
        if box.key then
            value = telemetry.getSensorSource(box.key):value()
            if box.format and value then
                value = box.format(value)
            end
        else
            value = box.value
        end

        utils.telemetryBox(x, y, w, h, box.color, box.title, value, box.unit, false)
    end
end


-- Main wakeup function
function preflight.wakeup(widget)
    lcd.invalidate(widget)
end

-- Main event function
function preflight.event(widget)

end

-- Main  configure function
function preflight.configure(widget)

end

-- Main  read function
function preflight.read(widget)

end

-- Main  write function
function preflight.write(widget)

end

return preflight
