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
    cols = 3,
    rows = 4,
    padding = 4
}

local boxes = {
  {
    col = 1,
    row = 1,
    rowspan = 2,
    type = "modelimage"
  },
  {
    col = 1,
    row = 3,
    type = "telemetry",
    source = "rssi",
    nosource = "-",
    title = "LQ",
    unit = "dB",
    titlepos = "bottom",
    transform = "floor"
  },
  {
    col = 1,
    row = 4,
    type = "governor",
    nosource = "-",
    title = "GOVERNOR",
    titlepos = "bottom"
  },
  {
    col = 2,
    row = 1,
    rowspan = 2,
    type = "telemetry",
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
        color = "red"
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
        color = "orange"
      },
      {
        -- 100% of (gmin→gmax) → green
        value = function(box, currentValue)
          local cfg   = rfsuite.session.batteryConfig
          local cells = (cfg and cfg.batteryCellCount) or 3
          local maxV  = (cfg and cfg.vbatmaxcellvoltage) or 4.2
          return math.max(0, cells * maxV)
        end,
        color = "green"
      }
    }
  },
  {
    col = 2,
    row = 3,
    rowspan = 2,
    type = "telemetry",
    source = "current",
    nosource = "-",
    title = "CURRENT",
    unit = "A",
    titlepos = "bottom"
  },
  {
    col = 3,
    row = 1,
    rowspan = 2,
    type = "telemetry",
    source = "fuel",
    nosource = "-",
    title = "FUEL",
    unit = "%",
    titlepos = "bottom",
    transform = "floor",

    -- Here are our “dynamic” thresholds for fuel (0‒100%):
    --   • Anything < 30% → red
    --   • Anything < 50% → orange
    --   • Anything ≤ 100% → green
    thresholds = {
      {
        value = function(box, currentValue)
          -- Always 0 → 100 range for “fuel,” so gmin=0, gmax=100:
          local gmin = 0
          local gmax = 100
          return gmin + 0.30 * (gmax - gmin)   -- → 30
        end,
        color = "red"
      },
      {
        value = function(box, currentValue)
          local gmin = 0
          local gmax = 100
          return gmin + 0.50 * (gmax - gmin)   -- → 50
        end,
        color = "orange"
      },
      {
        value = function(box, currentValue)
          local gmax = 100
          return gmax                           -- → 100
        end,
        color = "green"
      }
    }
  },
  {
    col = 3,
    row = 3,
    rowspan = 2,
    type = "telemetry",
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
