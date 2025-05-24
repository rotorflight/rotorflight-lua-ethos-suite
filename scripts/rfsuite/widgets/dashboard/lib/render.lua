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

local render = {}

local utils = assert(
    rfsuite.compiler.loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/lib/utils.lua")
)()

--[[
    Draws a telemetry data box.
    Applies any transformation to the value if specified.
    Args: x, y, w, h - box position and size
          box - box definition table (includes source, transform, color, etc.)
          telemetry - telemetry source accessor
]]
function render.telemetryBox(x, y, w, h, box, telemetry)
    local value = nil
    if box.source then
        local sensor = telemetry and telemetry.getSensorSource(box.source)
        value = sensor and sensor:value()
        if type(box.transform) == "string" and math[box.transform] then
            value = value and math[box.transform](value)
        elseif type(box.transform) == "function" then
            value = value and box.transform(value)
        elseif type(box.transform) == "number" then
            value = value and box.transform(value)
        end
    end
    local displayValue = value
    local displayUnit = box.unit
    if value == nil then
        displayValue = box.novalue or "-"
        displayUnit = nil
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, displayUnit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws a static text box.
    Args: x, y, w, h - box position and size
          box - box definition table (includes title, value, etc.)
]]
function render.textBox(x, y, w, h, box)
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, box.value, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws an image box.
    Uses box.value or box.source as the image, or defaults if missing.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.imageBox(x, y, w, h, box)
    utils.imageBox(
        x, y, w, h,
        box.color, box.title,
        box.value or box.source or "widgets/dashboard/default_image.png",
        box.imagewidth, box.imageheight, box.imagealign,
        box.bgcolor, box.titlealign, box.titlecolor, box.titlepos,
        box.imagepadding, box.imagepaddingleft, box.imagepaddingright, box.imagepaddingtop, box.imagepaddingbottom
    )
end

--[[
    Draws a model image box (usually shows the model's icon).
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.modelImageBox(x, y, w, h, box)
    utils.modelImageBox(
        x, y, w, h,
        box.color, box.title,
        box.imagewidth, box.imageheight, box.imagealign,
        box.bgcolor, box.titlealign, box.titlecolor, box.titlepos,
        box.imagepadding, box.imagepaddingleft, box.imagepaddingright, box.imagepaddingtop, box.imagepaddingbottom
    )
end

--[[
    Draws a governor status box.
    Converts sensor value to state string via rfsuite.utils.getGovernorState.
    Args: x, y, w, h - box position and size
          box - box definition table
          telemetry - telemetry source accessor
]]
function render.governorBox(x, y, w, h, box, telemetry)
    local value = nil
    local sensor = telemetry and telemetry.getSensorSource("governor")
    value = sensor and sensor:value()
    local displayValue = rfsuite.utils.getGovernorState(value)
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws the craft name box.
    Falls back to novalue if craft name is not set or empty.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.craftnameBox(x, y, w, h, box)
    local displayValue = rfsuite.session.craftName
    if displayValue == nil or (type(displayValue) == "string" and displayValue:match("^%s*$")) then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws an API version box.
    Shows the current API version or novalue if not available.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.apiversionBox(x, y, w, h, box)
    local displayValue = rfsuite.session.apiVersion
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws a session variable box.
    Looks up the value from rfsuite.session using box.source.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.sessionBox(x, y, w, h, box)
    local displayValue = rfsuite.session[box.source]
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Draws a blackbox storage usage box.
    Shows used/total space in MB if available, else novalue.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.blackboxBox(x, y, w, h, box)
    local displayValue = nil
    local totalSize = rfsuite.session.bblSize
    local usedSize = rfsuite.session.bblUsed
    if totalSize and usedSize then
        displayValue = string.format(
            "%.1f/%.1f " .. rfsuite.i18n.get("app.modules.status.megabyte"),
            usedSize / (1024 * 1024),
            totalSize / (1024 * 1024)
        )
    end
    if displayValue == nil then
        displayValue = box.novalue or "-"
    end
    utils.telemetryBox(
        x, y, w, h,
        box.color, box.title, displayValue, box.unit, box.bgcolor,
        box.titlealign, box.valuealign, box.titlecolor, box.titlepos,
        box.titlepadding, box.titlepaddingleft, box.titlepaddingright, box.titlepaddingtop, box.titlepaddingbottom,
        box.valuepadding, box.valuepaddingleft, box.valuepaddingright, box.valuepaddingtop, box.valuepaddingbottom
    )
end

--[[
    Calls a custom function stored in box.value (if it is a function).
    For advanced or custom box render logic.
    Args: x, y, w, h - box position and size
          box - box definition table
]]
function render.functionBox(x, y, w, h, box)
    if box.value and type(box.value) == "function" then
        box.value(x, y, w, h)
    end
end

--[[
    Dispatcher for rendering boxes by type.
    Looks up the render function from a map and calls it with box details.
    Args: boxType - the box type string (e.g., "telemetry", "text", etc.)
          x, y, w, h - box position and size
          box - box definition table
          telemetry - telemetry accessor (optional)
]]
function render.renderBox(boxType, x, y, w, h, box, telemetry)
    local funcMap = {
        telemetry = render.telemetryBox,
        text = render.textBox,
        image = render.imageBox,
        modelimage = render.modelImageBox,
        governor = render.governorBox,
        craftname = render.craftnameBox,
        apiversion = render.apiversionBox,
        session = render.sessionBox,
        blackbox = render.blackboxBox,
        ["function"] = render.functionBox,
    }
    local fn = funcMap[boxType]
    if fn then
        return fn(x, y, w, h, box, telemetry)
    end
end

return render
