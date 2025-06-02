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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]]

--[[

================================================================================
                                WIDGET OPTION REFERENCE
================================================================================

-------------------------------  DIAL BOX OPTIONS  -----------------------------
{
    type = "dial",               -- Required: "dial"
    col, row,                    -- Required: grid position
    -- colspan, rowspan,         -- Optional: grid span
    -- source,                   -- Telemetry field name
    -- min, max,                 -- Value range (number/function)
    -- unit,                     -- Value unit ("V", "%", etc.)
    -- transform,                -- "floor", "ceil", "round", function, number
    -- novalue,                  -- Placeholder if data missing
    -- decimals,                 -- Number of decimal places
    -- dial,                     -- Panel image: id, string path, or function
    -- aspect,                   -- "fit", "fill", "stretch", "original"
    -- align,                    -- "center", "top-left", etc.
    -- needlecolor,              -- Needle color
    -- needlehubcolor,           -- Needle hub/cap color
    -- needlehubsize,            -- Hub/cap radius (px)
    -- needlethickness,          -- Needle width (px)
    -- needlestartangle,         -- Needle start angle (deg)
    -- needlesweepangle,         -- Needle sweep angle (deg)
    -- needleendangle,           -- Needle end angle (deg, overrides sweep)
    -- bgcolor,                  -- Widget background color
    -- selectcolor,              -- Selected/highlight color
    -- selectborder,             -- Selected border width
    -- title,                    -- Label (above/below)
    -- titlepos,                 -- "top", "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- "center", "left", "right"
    -- font,                     -- Value font
    -- textColor,                -- Value color
    -- textoffsetx,              -- X offset for value
    -- titlepadding,             -- Padding (all)
    -- titlepaddingleft,         -- Padding left
    -- titlepaddingright,        -- Padding right
    -- titlepaddingtop,          -- Padding top
    -- titlepaddingbottom,       -- Padding bottom
    -- customRenderFunction,     -- Advanced custom drawing
}

-----------------------------  HEATRING BOX OPTIONS  ---------------------------
{
    type = "heatring",           -- Required: "heatring"
    col, row,                    -- Required: grid position
    -- colspan, rowspan,         -- Optional: grid span
    -- source,                   -- Telemetry field name
    -- min, max,                 -- Value range (number/function)
    -- unit,                     -- Value unit ("V", "%", etc.)
    -- transform,                -- "floor", "ceil", "round", function
    -- novalue,                  -- Placeholder if data missing
    -- ringsize,                 -- Relative ring size (0.1–1.0)
    -- ringColor,                -- Default ring color
    -- thresholds,               -- { {value, color}, ... } for dynamic color
    -- bgcolor,                  -- Widget background
    -- title,                    -- Label
    -- titlepos,                 -- "above", "below"
    -- titlealign,               -- "center", "left", "right"
    -- titleoffset,              -- Title offset (px)
    -- font,                     -- Value font
    -- textColor,                -- Value text color
    -- textalign,                -- "center", "left", "right"
    -- textoffset,               -- Y offset for value text
}

----------------------------  ARCDIAL BOX OPTIONS  -----------------------------
{
    type = "arcdial",            -- Required: "arcdial"
    col, row,                    -- Required: grid position
    -- colspan, rowspan,         -- Optional: grid span
    -- source,                   -- Telemetry field
    -- min, max,                 -- Value range
    -- unit,                     -- Value unit
    -- transform,                -- "floor", "ceil", "round", function
    -- novalue,                  -- Value if missing
    -- bandLabels,               -- Section label array
    -- bandColors,               -- Section color array
    -- startAngle,               -- Arc start angle (deg, default 180)
    -- sweep,                    -- Arc sweep (deg, default 180)
    -- arcBgColor,               -- Arc background color
    -- thresholds,               -- Not common; see arcgauge for colored arcs
    -- needlecolor,              -- Needle color
    -- needlehubcolor,           -- Needle hub/cap color
    -- needlehubsize,            -- Hub/cap radius
    -- needlethickness,          -- Needle width
    -- bgcolor,                  -- Widget background
    -- aspect,                   -- Image scaling (rarely used here)
    -- align,                    -- "center", etc.
    -- title,                    -- Label
    -- titlepos,                 -- "top", "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- "center", "left", "right"
    -- font,                     -- Value font
    -- textColor,                -- Value color
}

---------------------------  ARCGUAGE BOX OPTIONS  -----------------------------
{
    type = "arcgauge",           -- Required: "arcgauge"
    col, row,                    -- Required: grid position
    -- colspan, rowspan,         -- Optional: grid span
    -- source,                   -- Telemetry field
    -- gaugemin, gaugemax,       -- Min/max value (alternative to min/max)
    -- min, max,                 -- Value range (number/function)
    -- unit,                     -- Value unit
    -- transform,                -- "floor", "ceil", "round", function
    -- novalue,                  -- Value if missing
    -- decimals,                 -- Decimal places
    -- arcOffsetY,               -- Arc vertical offset
    -- arcThickness,             -- Arc thickness multiplier
    -- startAngle,               -- Arc start angle (deg)
    -- sweep,                    -- Arc sweep (deg)
    -- arcBgColor,               -- Arc background color
    -- arcColor,                 -- Foreground arc color (overridden by thresholds)
    -- thresholds,               -- { {value, color}, ... } for dynamic color
    -- title,                    -- Label
    -- titlepos,                 -- "top", "bottom"
    -- titlecolor,               -- Label color
    -- titlealign,               -- "center", "left", "right"
    -- font,                     -- Value font
    -- textColor,                -- Value color
    -- textoffsetx,              -- X offset for value
    -- titlepadding,             -- Padding (all)
    -- titlepaddingleft,         -- Padding left
    -- titlepaddingright,        -- Padding right
    -- titlepaddingtop,          -- Padding top
    -- titlepaddingbottom,       -- Padding bottom
    -- subText,                  -- Extra text below value
    -- valueFormat,              -- Custom value formatting function
}

---------------------------  GUAGE WIDGET OPTIONS  -----------------------------

{
    type = "gauge",               -- Required: widget type

    -- Grid/Placement
    col, row,                     -- Required: grid position
    -- colspan, rowspan,          -- Optional: grid span

    -- Telemetry/Data
    -- source,                    -- Telemetry field name or function(box, telemetry)
    -- min, max,                  -- Value range for display (number/function)
    -- gaugemin, gaugemax,        -- Value range for FILL (overrides min/max for fill)
    -- unit,                      -- Unit string ("V", "%", etc.)
    -- transform,                 -- "floor", "ceil", "round", function, number
    -- novalue,                   -- Placeholder if value is missing
    -- decimals,                  -- Number of decimal places

    -- Gauge Appearance
    -- gaugeorientation,          -- "vertical" (default) or "horizontal"
    -- gaugecolor,                -- Fill color (default yellow)
    -- gaugebgcolor,              -- Fill background color
    -- bgcolor,                   -- Widget background
    -- roundradius,               -- Rounded rectangle corner radius (px)
    -- thresholds = {             -- Table of dynamic color breaks (optional)
    --     {value=..., color=..., textcolor=...}, ...
    -- },

    -- Padding
    -- gaugepadding,              -- Padding (all sides, px)
    -- gaugepaddingleft,          -- Left gauge padding
    -- gaugepaddingright,         -- Right gauge padding
    -- gaugepaddingtop,           -- Top gauge padding
    -- gaugepaddingbottom,        -- Bottom gauge padding

    -- Value Text Display
    -- color,                     -- Value text color
    -- valuealign,                -- "center" (default), "left", "right"
    -- valuepadding,              -- Value text padding (all)
    -- valuepaddingleft,          -- Value text left padding
    -- valuepaddingright,         -- Value text right padding
    -- valuepaddingtop,           -- Value text top padding
    -- valuepaddingbottom,        -- Value text bottom padding

    -- Title Text Display
    -- title,                     -- Widget label/title
    -- titlepos,                  -- "top" (default) or "bottom"
    -- titlecolor,                -- Title color
    -- titlealign,                -- "center" (default), "left", "right"
    -- titlepadding,              -- Title padding (all)
    -- titlepaddingleft,          -- Title padding left
    -- titlepaddingright,         -- Title padding right
    -- titlepaddingtop,           -- Title padding top
    -- titlepaddingbottom,        -- Title padding bottom
    -- gaugebelowtitle,           -- true/false: title outside gauge area (default false)

    -- Advanced/Custom
    -- customRenderFunction,      -- For advanced custom drawing (rarely used)
}

================================================================================
                       END OF WIDGET OPTION REFERENCE
================================================================================

]]

--------------------------------------------------------------------------------
-- ACTUAL DASHBOARD CONFIG BELOW (edit/add your widgets here!)
--------------------------------------------------------------------------------

local layout = {
    cols = 3,
    rows = 3,
    padding = 4,
}

local boxes = {

    -- DIAL
    {
        type = "dial",
        col = 1, row = 1,
        title = "Voltage",
        unit = "v",
        titlepos = "bottom",
        source = "voltage",
        aspect = "fit",
        align = "center",
        dial = 1,
        needlecolor = "red",
        needlehubcolor = "red",
        needlehubsize = 5,
        needlethickness = 4,
        font = "FONT_S",
        min = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        max = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
    },

    -- HEATRING
    {
        type = "heatring",
        col = 2, row = 1,
        title = "RPM",
        min = 0,
        max = 12000,
        thresholds = {
            { value = 3000,  fillcolor = "green" },
            { value = 6000,  fillcolor = "orange" },
            { value = 9000,  fillcolor = "orange" },
            { value = 12000, fillcolor = "red" },
        },
        ringsize = 0.8,
        textoffset = 0,
        titleoffset = 0,
        textalign = "center",
        titlealign = "center",
        titlepos = "below",
        unit = "",
        transform = "floor",
        textcolor = "white",
        source = "rpm",
    },

    -- ARCGUAGE
    {
        type = "arcgauge",
        col = 1, row = 2,
        source = "temp_esc", 
        title = "ESC Temp", 
        titlepos = "bottom",
        gaugemin = 0, 
        gaugemax = 140, 
        unit = "°", 
        textcolor = "white", 
        font = "FONT_STD", 
        transform = "floor", 
        textoffsetx = 12,
        fillbgcolor = "lightgrey", 
        arcOffsetY = 4, 
        arcThickness = 1, 
        startAngle = 225, 
        sweep = 270,
        thresholds = {
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
        }
    },

    -- ARCDIAL
    {
        type = "arcdial",
        col = 2, row = 2,
        title = "Fuel",
        titlepos = "bottom",
        titlecolor = "white",
        unit = "%",
        source = "fuel",
        min = function() return 0 end,
        max = function() return 100 end,
        bandLabels = {"Low", "OK", "High"},
        bandColors = {"red", "orange", "green"},
        startangle = 180,
        sweep = 180,
        needlecolor = "black",
        needlehubcolor = "red",
        needlehubsize = 12,
        needlethickness = 6,
        aspect = "fit",
        align = "center",
    },

    -- FUEL GAUGE
    {
        col = 1, row = 3,
        type = "gauge",
        source = "fuel",
        gaugemin = 0,
        gaugemax = 100,
        roundradius = 9,
        fillbgcolor = "grey",
        gaugeorientation = "horizontal",
        gaugepadding = 8,
        gaugebelowtitle = true,
        title = "FUEL",
        unit = "%",
        textcolor = "white",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        thresholds = {
            { value = 20,  fillcolor = "red",    textcolor = "white" },
            { value = 50,  fillcolor = "orange", textcolor = "black" },
        },
        fillcolor = "green",
    },

    -- VOLTAGE GAUGE
    {col = 2, row = 3, type = "voltagegauge", title = "Voltage"},

    -- BATTERY
    {
        col = 3, row = 1,
        type = "battery",
        source = "voltage",
        gaugemin = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
            return math.max(0, cells * minV)
        end,
        gaugemax = function()
            local cfg = rfsuite.session.batteryConfig
            local cells = (cfg and cfg.batteryCellCount) or 3
            local maxV = (cfg and cfg.vbatmaxcellvoltage) or 4.2
            return math.max(0, cells * maxV)
        end,
        fillbgcolor = "gray",
        gaugeorientation = "horizontal",
        gaugepadding = 8,
        gaugebelowtitle = true,
        showvalue = true,
        title = "VOLTAGE",
        unit = "V",
        textcolor = "black",
        valuealign = "center",
        titlealign = "center",
        titlepos = "bottom",
        titlecolor = "white",
        fillcolor = "green",
        thresholds = {
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                    return cells * minV * 1.2
                end,
                fillcolor = "red", textcolor = "white"
            },
            {
                value = function()
                    local cfg = rfsuite.session.batteryConfig
                    local cells = (cfg and cfg.batteryCellCount) or 3
                    local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                    return cells * warnV * 1.2
                end,
                fillcolor = "orange", textcolor = "black"
            }
        },        
    },

    -- ARC MAX GAUGE
    {
        type = "arcmaxgauge",
        col = 3, row = 2, rowspan = 2,
                source = "temp_esc", 
        title = "ESC Temp", 
        titlepos = "bottom",
        gaugemin = 0, 
        gaugemax = 140, 
        unit = "°", 
        textcolor = "white", 
        font = "FONT_STD", 
        transform = "floor", 
        textoffsetx = 12,
        fillbgcolor = "lightgrey", 
        arcOffsetY = 4, 
        arcThickness = 1, 
        startAngle = 225, 
        sweep = 270,
        thresholds = {
            { value = 70,  fillcolor = "green"  },
            { value = 90,  fillcolor = "orange" },
            { value = 140, fillcolor = "red"    }
        }
    },
}

return {
    layout = layout,
    boxes = boxes,
    wakeup = wakeup,
    event = event,
    paint = paint,
    overlayMessage = nil,
    customRenderFunction = customRenderFunction,
    scheduler = {
        wakeup_interval = 0.25,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.5,            -- Interval (seconds) to run paint script when display is visible 
    }    
}
