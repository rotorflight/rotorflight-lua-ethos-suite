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

local telemetry = rfsuite.tasks.telemetry
local utils = rfsuite.widgets.dashboard.utils

local layout = {
    cols = 20,
    rows = 8,
    padding = 1,
    bgcolor = "black",
    --showgrid = lcd.RGB(100, 100, 100)  -- or any color you prefer
}

local boxes = {
  {
    col = 1,
    row = 1,
    colspan = 8,
    rowspan = 3,
    type = "image",
    subtype = "model",
    bgcolor = "black",
  },   
  {
    col = 1,
    row = 4,
    colspan = 4,
    rowspan = 3,    
    type = "text",
    subtype = "governor",
    nosource = "-",
    title = "GOVERNOR",
    titlepos = "bottom",
    bgcolor = "black",  
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
    col = 5,
    row = 4,
    colspan = 4,
    rowspan = 3,
    type = "text",
    subtype = "telemetry",
    source = "rpm",
    nosource = "-",
    unit = "",
    transform = "floor",
    title = "HEADSPEED",
    titlepos = "bottom",
    bgcolor = "black",
  },  
  {
    col = 1,
    row = 7,
    colspan = 2,
    rowspan = 2,
    type = "text",
    subtype = "telemetry",
    source = "pid_profile",    
    bgcolor = "black",
    title = "PROFILE",
    titlepos = "bottom",
    transform = "floor"
  },   
  {
    col = 3,
    row = 7,
    colspan = 2,
    rowspan = 2,
    type = "text",
    subtype = "telemetry",
    source = "rate_profile",    
    bgcolor = "black",
    title = "RATES",
    titlepos = "bottom",
    transform = "floor"
  },       
  {
      col = 5, 
      row = 7,
      rowspan = 2,
      colspan = 2,
      type = "time", 
      subtype = "count",
      title = "FLIGHTS",
      titlepos = "bottom",
      bgcolor = "black",
  }, 
  {
      col = 7, 
      row = 7,
      rowspan = 2,
      colspan = 2,
      type = "text",
      subtype = "telemetry",
      source = "rssi",
      nosource = "-",
      title = "LQ",
      unit = "dB",
      titlepos = "bottom",
      transform = "floor",
      bgcolor = "black",
  },   
  {
    col = 9,
    row = 7,
    colspan = 6,
    rowspan = 2,
    type = "time",
    subtype = "flight",  
    bgcolor = "black",
    title = "TIME",
    titlepos = "bottom",
  },    
  {
      col = 15, 
      row = 7,
      rowspan = 2,
      colspan = 6,
      type = "text", 
      subtype = "blackbox",
      title = "BLACKBOX",
      titlepos = "bottom",
      bgcolor = "black",
  },   
  {
      type = "gauge",
      subtype = "arc",
      col = 9, 
      row = 1,
      rowspan = 6,
      colspan = 6,
      thickness = 30,
      source = "fuel",
      unit = "%",
      transform = "floor",
      min = 0,
      max = 100,
      font = "FONT_XL",
      arcbgcolor = "lightgrey",
      title = "FUEL",
      titlepos = "bottom",
      bgcolor = "black",
      thresholds = {
          { value = 30,  fillcolor = "red",    textcolor = "white" },
          { value = 50,  fillcolor = "orange", textcolor = "white" },
          { value = 140, fillcolor = "green",  textcolor = "white" }
      },
  },  
  {
      col = 15, 
      row = 1,
      rowspan = 6,
      colspan = 6,
      type = "gauge",
      subtype = "arc",
      source = "voltage",
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
      fillbgcolor = "grey",
      title = "VOLTAGE",
      font = "FONT_XL",
      thickness = 30,
      titlepos = "bottom",
      fillcolor = "green",
      bgcolor = "black",
      thresholds = {
          {
              value = function()
                  local cfg = rfsuite.session.batteryConfig
                  local cells = (cfg and cfg.batteryCellCount) or 3
                  local minV = (cfg and cfg.vbatmincellvoltage) or 3.0
                  return cells * minV * 1.2
              end,
              fillbgcolor = "red",
              textcolor = "white"
          },
          {
              value = function()
                  local cfg = rfsuite.session.batteryConfig
                  local cells = (cfg and cfg.batteryCellCount) or 3
                  local warnV = (cfg and cfg.vbatwarningcellvoltage) or 3.5
                  return cells * warnV * 1.2
              end,
              fillbgcolor = "orange",
              textcolor = "white"
          }
      }
  }, 
}


return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        wakeup_interval = 0.1,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.1,            -- Interval (seconds) to run paint script when display is visible 
    }    
}
