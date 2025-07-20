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
]]--

local i18n = rfsuite.i18n.get
local utils = rfsuite.widgets.dashboard.utils
local boxes_cache = nil
local themeconfig = nil
local lastScreenW = nil

local darkMode = {
    textcolor       = "white",
    titlecolor      = "white",
    bgcolor         = "black",
    fillcolor       = "green",
    fillbgcolor     = "darkgrey",
    accentcolor     = "white",
    rssifillcolor   = "green",
    rssifillbgcolor = "darkgrey",
    txaccentcolor   = "grey",
    txfillcolor     = "green",
    txbgfillcolor   = "darkgrey",
    bgcolortop      = "black",
}

local lightMode = {
    textcolor       = "black",
    titlecolor      = "black",
    bgcolor         = "white",
    fillcolor       = "green",
    fillbgcolor     = "lightgrey",
    accentcolor     = "darkgrey",
    rssifillcolor   = "green",
    rssifillbgcolor = "grey",
    txaccentcolor   = "darkgrey",
    txfillcolor     = "green",
    txbgfillcolor   = "grey",
    bgcolortop =    "grey",
}

-- User voltage min/max override support
local function getUserVoltageOverride(which)
  local prefs = rfsuite.session and rfsuite.session.modelPreferences
  if prefs and prefs["system/@default"] then
    local v = tonumber(prefs["system/@default"][which])
    -- Only use override if it is present and different from the default 6S values
    -- (Defaults: min=18.0, max=25.2)
    if which == "v_min" and v and math.abs(v - 18.0) > 0.05 then return v end
    if which == "v_max" and v and math.abs(v - 25.2) > 0.05 then return v end
  end
  return nil
end

-- alias current mode
local colorMode = lcd.darkMode() and darkMode or lightMode

-- Theme based configuration settings
local theme_section = "system/@default"

local THEME_DEFAULTS = {
    rpm_min      = 0,
    rpm_max      = 3000,
    bec_min      = 3.0,
    bec_max      = 13.0,
    esctemp_warn = 90,
    esctemp_max  = 140,
    tx_min       = 7.2,
    tx_warn      = 7.4,
    tx_max       = 8.4
}

-- Theme Options based on screen width
local function getThemeOptionKey(W)
    if     W == 800 then return "ls_full"
    elseif W == 784 then return "ls_std"
    elseif W == 640 then return "ss_full"
    elseif W == 630 then return "ss_std"
    elseif W == 480 then return "ms_full"
    elseif W == 472 then return "ms_std"
    end
end

-- Theme Options based on screen width
local themeOptions = {
    -- Large screens - (X20 / X20RS / X18RS etc) Full/Standard
    ls_full = { 
        font = "FONT_XXL", 
        advfont = "FONT_M", 
        thickness = 25, 
        batteryframethickness = 4, 
        titlepaddingbottom = 15, 
        valuepaddingleft = 25, 
        valuepaddingtop = 20, 
        valuepaddingbottom = 25, 
        gaugepaddingtop = 20, 
        gaugepadding = 20
    },

    ls_std  = { 
        font = "FONT_XL", 
        advfont = "FONT_M", 
        thickness = 35, 
        batteryframethickness = 4, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 75, 
        valuepaddingtop = 5, 
        valuepaddingbottom = 25, 
        gaugepaddingtop = 5, 
        gaugepadding = 10,
    },


    -- Medium screens (X18 / X18S / TWXLITE) - Full/Standard
    ms_full = { 
        font = "FONT_XXL", 
        advfont = "FONT_M", 
        thickness = 27, 
        batteryframethickness = 4, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 20, 
        valuepaddingtop = 5, 
        valuepaddingbottom = 15, 
        gaugepaddingtop = 5, 
        gaugepadding = 10,
    },

    ms_std  = { 
        font = "FONT_XL", 
        advfont = "FONT_S", 
        thickness = 20, 
        batteryframethickness = 2, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 20, 
        valuepaddingtop = 10, 
        valuepaddingbottom = 25, 
        gaugepaddingtop = 5, 
        gaugepadding = 5,
    },

    -- Small screens - (X14 / X14S) Full/Standard
    ss_full = { 
        font = "FONT_XL", 
        advfont = "FONT_M", 
        thickness = 25,  
        batteryframethickness = 4, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 20, 
        valuepaddingtop = 5, 
        valuepaddingbottom = 15, 
        gaugepaddingtop = 5, 
        gaugepadding = 10,
    },

    ss_std  = { 
        font = "FONT_XL", 
        advfont = "FONT_S", 
        thickness = 22,  
        batteryframethickness = 2, 
        titlepaddingbottom = 0, 
        valuepaddingleft = 20, 
        valuepaddingtop = 10, 
        valuepaddingbottom = 25, 
        gaugepaddingtop = 5, 
        gaugepadding = 10,
    },
}

local function getThemeValue(key)
    if rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section] then
        local val = rfsuite.session.modelPreferences[theme_section][key]
        val = tonumber(val)
        if val ~= nil then return val end
    end
    return THEME_DEFAULTS[key]
end

-- Caching for boxes
local lastScreenW = nil
local boxes_cache = nil
local themeconfig = nil
local headeropts = utils.getHeaderOptions()

-- Theme Layout
local layout = {
    cols    = 8,
    rows    = 4,
    padding = 4,
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

local header_layout = {
    height  = headeropts.height,
    cols    = 7,
    rows    = 1,
    padding = 0,
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

-- Boxes
local function buildBoxes(W)
    
    -- Object based options determined by screensize
    local opts = themeOptions[getThemeOptionKey(W)] or themeOptions.unknown

return {
  {
    col = 1,
    row = 1,
    rowspan = 2,
    colspan = 2,
    type = "image",
    subtype = "model"
  },
  {
    col = 1,
    row = 3,
    colspan = 1,
    type = "text",
    subtype = "telemetry",
    source = "link",
    nosource = "-",
    title = i18n("widgets.dashboard.lq"):upper(),
    unit = "dB",
    titlepos = "bottom",
    transform = "floor",
    titlecolor = colorMode.textcolor,
    textcolor = colorMode.textcolor,
  },
  {
    col = 2,
    row = 3,
    type = "time",
    subtype = "flight",
    titlepos = "bottom",
    title = i18n("widgets.dashboard.timer"):upper(),
    titlecolor = colorMode.textcolor,
    textcolor = colorMode.textcolor,   
  },  
  {
    col = 1,
    row = 4,
    colspan = 2,
    type = "text",
    subtype = "governor",
    nosource = "-",
    title = i18n("widgets.dashboard.governor"):upper(),
    titlepos = "bottom",
    titlecolor = colorMode.textcolor,
    textcolor = colorMode.textcolor,    
    thresholds = {
          { value = i18n("widgets.governor.DISARMED"), textcolor = "red"    },
          { value = i18n("widgets.governor.OFF"),      textcolor = "red"    },
          { value = i18n("widgets.governor.IDLE"),     textcolor = "yellow" },
          { value = i18n("widgets.governor.SPOOLUP"),  textcolor = "blue"   },
          { value = i18n("widgets.governor.RECOVERY"), textcolor = "orange" },
          { value = i18n("widgets.governor.ACTIVE"),   textcolor = "green"  },
          { value = i18n("widgets.governor.THR-OFF"),  textcolor = "red"    },
      }
  },
  {
    col = 3,
    row = 1,
    rowspan = 2,
    colspan = 3,
    type = "text",
    subtype = "telemetry",
    source = "voltage",
    nosource = "-",
    title = i18n("widgets.dashboard.voltage"):upper(),
    unit = "v",
    titlepos = "bottom",
    titlecolor = colorMode.textcolor,
    textcolor = colorMode.textcolor,
    -- (same as before: these live here if you ever need .min/.max)
    min = function()
      local cfg   = rfsuite.session.batteryConfig
      local cells = (cfg and cfg.batteryCellCount) or 3
      local minV  = (cfg and cfg.vbatmincellvoltage) or 3.0
      return math.max(0, cells * minV)
    end,
    max = function()
      local cfg   = rfsuite.session.batteryConfig
      local cells = (cfg and cfg.batteryCellCount) or 3
      local maxV  = (cfg and cfg.vbatmaxcellvoltage) or 4.2
      return math.max(0, cells * maxV)
    end,

    thresholds = {
      {
        -- 30% of (gmin→gmax) → red
        value = function(box, currentValue)
          local cfg   = rfsuite.session.batteryConfig
          local cells = (cfg and cfg.batteryCellCount) or 3
          local minV  = (cfg and cfg.vbatmincellvoltage) or 3.0
          local maxV  = (cfg and cfg.vbatmaxcellvoltage) or 4.2
          local gmin  = math.max(0, cells * minV)
          local gmax  = math.max(0, cells * maxV)
          return gmin + 0.30 * (gmax - gmin)
        end,
        textcolor = "red"
      },
      {
        -- 50% of (gmin→gmax) → orange
        value = function(box, currentValue)
          local cfg   = rfsuite.session.batteryConfig
          local cells = (cfg and cfg.batteryCellCount) or 3
          local minV  = (cfg and cfg.vbatmincellvoltage) or 3.0
          local maxV  = (cfg and cfg.vbatmaxcellvoltage) or 4.2
          local gmin  = math.max(0, cells * minV)
          local gmax  = math.max(0, cells * maxV)
          return gmin + 0.50 * (gmax - gmin)
        end,
        textcolor = "orange"
      },
      {
        -- 100% of (gmin→gmax) → green
        value = function(box, currentValue)
          local cfg   = rfsuite.session.batteryConfig
          local cells = (cfg and cfg.batteryCellCount) or 3
          local maxV  = (cfg and cfg.vbatmaxcellvoltage) or 4.2
          return math.max(0, cells * maxV)
        end,
        textcolor = "green"
      }
    }
  },
  {
    col = 3,
    row = 3,
    rowspan = 2,
    colspan = 3,
    type = "text",
    subtype = "telemetry",
    source = "current",
    nosource = "-",
    title = i18n("widgets.dashboard.current"):upper(),
    unit = "A",
    titlepos = "bottom",
    titlecolor = colorMode.textcolor,
    textcolor = colorMode.textcolor,    
  },
  {
    col = 6,
    row = 1,
    rowspan = 2,
    colspan = 3,
    type = "text",
    subtype = "telemetry",
    source = "smartfuel",
    nosource = "-",
    title = i18n("widgets.dashboard.fuel"):upper(),
    unit = "%",
    titlepos = "bottom",
    transform = "floor",
    thresholds = {
      { value = 30, textcolor = "red" },
      { value = 60, textcolor = "orange" },
      { value = 100, textcolor = "green" }
    },
    titlecolor = colorMode.textcolor,
    textcolor = colorMode.textcolor,    
  },
  {
    col = 6,
    row = 3,
    colspan = 3,
    rowspan = 2,
    type = "text",
    subtype = "telemetry",
    source = "rpm",
    nosource = "-",
    title = i18n("widgets.dashboard.rpm"):upper(),
    unit = "rpm",
    titlepos = "bottom",
    transform = "floor",
    titlecolor = colorMode.textcolor,
    textcolor = colorMode.textcolor,    
  },
    }

end

local header_boxes = {
-- Craftname
    { 
        col = 1, 
        row = 1, 
        colspan = 2, 
        type = "text", 
        subtype = "craftname",
        font = headeropts.font, 
        valuealign = "left", 
        valuepaddingleft = 5,
        bgcolor = colorMode.bgcolortop, 
        titlecolor = colorMode.titlecolor, 
        textcolor = colorMode.textcolor 
    },

    -- RF Logo
    { 
        col = 3, 
        row = 1, 
        colspan = 3, 
        type = "image", 
        subtype = "image",
        bgcolor = colorMode.bgcolortop 
    },

    -- TX Battery
    { 
        col = 6, 
        row = 1,
        type = "gauge", 
        subtype = "bar", 
        source = "txbatt",
        font = headeropts.font,
        battery = true, 
        batteryframe = true, 
        hidevalue = true,
        valuealign = "left", 
        batterysegments = 4, 
        batteryspacing = 1, 
        batteryframethickness  = 2,
        batterysegmentpaddingtop = headeropts.batterysegmentpaddingtop,
        batterysegmentpaddingbottom = headeropts.batterysegmentpaddingbottom,
        batterysegmentpaddingleft = headeropts.batterysegmentpaddingleft,
        batterysegmentpaddingright = headeropts.batterysegmentpaddingright,
        gaugepaddingright = headeropts.gaugepaddingright,
        gaugepaddingleft = headeropts.gaugepaddingleft,
        gaugepaddingbottom = headeropts.gaugepaddingbottom,
        gaugepaddingtop = headeropts.gaugepaddingtop,
        fillbgcolor = colorMode.txbgfillcolor, 
        bgcolor = colorMode.bgcolortop,
        accentcolor = colorMode.txaccentcolor, 
        textcolor = colorMode.textcolor,
        min = getThemeValue("tx_min"), 
        max = getThemeValue("tx_max"), 
        thresholds = {
            { value = getThemeValue("tx_warn"), fillcolor = "orange" },
            { value = getThemeValue("tx_max"), fillcolor = colorMode.txfillcolor }
        }
    },

    -- RSSI
    { 
        col = 7, 
        row = 1,
        type = "gauge", 
        subtype = "step", 
        source = "rssi",
        font = "FONT_XS", 
        stepgap = 2, 
        stepcount = 5, 
        decimals = 0,
        valuealign = "left",
        barpaddingleft = headeropts.barpaddingleft,
        barpaddingright = headeropts.barpaddingright,
        barpaddingbottom = headeropts.barpaddingbottom,
        barpaddingtop = headeropts.barpaddingtop,
        valuepaddingleft = headeropts.valuepaddingleft,
        valuepaddingbottom = headeropts.valuepaddingbottom,
        bgcolor = colorMode.bgcolortop, 
        textcolor = colorMode.textcolor, 
        fillcolor = colorMode.rssifillcolor,
        fillbgcolor = colorMode.rssifillbgcolor,
    },
}

local function boxes()
    local config = rfsuite and rfsuite.session and rfsuite.session.modelPreferences and rfsuite.session.modelPreferences[theme_section]
    local W = lcd.getWindowSize()
    if boxes_cache == nil or themeconfig ~= config or lastScreenW ~= W then
        boxes_cache = buildBoxes(W)
        themeconfig = config
        lastScreenW = W
    end
    return boxes_cache
end

return {
  layout = layout,
  boxes = boxes,
  header_boxes = header_boxes,
  header_layout = header_layout,
  scheduler = {
        spread_scheduling = true,         -- (optional: spread scheduling over the interval to avoid spikes in CPU usage) 
        spread_scheduling_paint = false,  -- optional: spread scheduling for paint (if true, paint will be spread over the interval) 
        spread_ratio = 0.5                -- optional: manually override default ratio logic (applies if spread_scheduling is true)
  }    
}
