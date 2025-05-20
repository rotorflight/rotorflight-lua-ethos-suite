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

    -- Set background color based on theme
    rfsuite.widgets.dashboard.utils.setBackgroundColourBasedOnTheme()

    -- example 
    --rfsuite.widgets.dashboard.utils.telemetryBox(x, y, w, h, color, title, value, unit, titleTop)

    -- voltage
    local value = telemetry.getSensorSource("voltage"):value()
    rfsuite.widgets.dashboard.utils.telemetryBox(0, 2, 200, 100, nil, "VOLTAGE", value, "V", true)

    -- current
    local value = telemetry.getSensorSource("current"):value()
    rfsuite.widgets.dashboard.utils.telemetryBox(202, 2, 200, 100, 2, "CURRENT", value, "A", true)

    -- current
    local value = telemetry.getSensorSource("rpm"):value()
    value = value and math.floor(value)
    rfsuite.widgets.dashboard.utils.telemetryBox(404, 2, 200, 100, 3, "RPM", value, "RPM", true)

    -- STATUS
    rfsuite.widgets.dashboard.utils.telemetryBox(0, 104, 604, 100, 0, "", "POST-FLIGHT", "", false)


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
