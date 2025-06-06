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

local layout = {
    cols = 8,
    rows = 4,
    padding = 4
}

local boxes = {
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
    source = "rssi",
    nosource = "-",
    title = "LQ",
    unit = "dB",
    titlepos = "bottom",
    transform = "floor"
  },
  {
    col = 2,
    row = 3,
    type = "time",
    subtype = "flight",
    titlepos = "bottom",
    title = "TIMER",
  },  
  {
    col = 1,
    row = 4,
    colspan = 2,
    type = "text",
    subtype = "governor",
    nosource = "-",
    title = "GOVERNOR",
    titlepos = "bottom",
    thresholds = {
        { value = "DISARMED", textcolor = "red"    },
        { value = "OFF",      textcolor = "red"    },
        { value = "IDLE",     textcolor = "yellow" },
        { value = "SPOOLUP",  textcolor = "blue"   },
        { value = "RECOVERY", textcolor = "orange" },
        { value = "ACTIVE",   textcolor = "green"  },
        { value = "THR-OFF",  textcolor = "red"    },
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
    title = "VOLTAGE",
    unit = "v",
    titlepos = "bottom",

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
    title = "CURRENT",
    unit = "A",
    titlepos = "bottom"
  },
  {
    col = 6,
    row = 1,
    rowspan = 2,
    colspan = 3,
    type = "text",
    subtype = "telemetry",
    source = "fuel",
    nosource = "-",
    title = "FUEL",
    unit = "%",
    titlepos = "bottom",
    transform = "floor",
    thresholds = {
      { value = 30, textcolor = "red" },
      { value = 60, textcolor = "orange" },
      { value = 100, textcolor = "green" }
    }
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
    title = "RPM",
    unit = "rpm",
    titlepos = "bottom",
    transform = "floor"
  },
}



return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        wakeup_interval = 0.25,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = nil,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.5,            -- Interval (seconds) to run paint script when display is visible 
    }    
}
