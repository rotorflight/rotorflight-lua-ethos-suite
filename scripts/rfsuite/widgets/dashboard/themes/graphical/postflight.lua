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
    padding = 4
}

local boxes = {
  {
    col = 1,
    row = 1,
    colspan = 8,
    rowspan = 3,
    type = "image",
    subtype = "model",
    bgcolor = "transparent",
  },   
  {
    col = 1,
    row = 4,
    colspan = 4,
    rowspan = 3,    
    type = "text",
    subtype = "governor",
    nosource = "-",
    title = "Governor",
    titlepos = "bottom",
    bgcolor = "transparent",  
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
    title = "Headspeed",
    titlepos = "bottom",
    bgcolor = "transparent",
  },  
  {
    col = 1,
    row = 7,
    colspan = 2,
    rowspan = 2,
    type = "text",
    subtype = "telemetry",
    source = "pid_profile",    
    bgcolor = "transparent",
    title = "Profile",
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
    bgcolor = "transparent",
    title = "Rate",
    titlepos = "bottom",
    transform = "floor"
  },  
  {
    col = 6,
    row = 7,
    colspan = 2,
    rowspan = 2,
    type = "time",
    subtype = "flight",  
    bgcolor = "transparent",
    title = "Timer",
    titlepos = "bottom",
  },    
  {
      type = "gauge",
      subtype = "arcmax",
      col = 9, 
      row = 1,
      rowspan = 6,
      colspan = 6,
      source = "current",
      transform = "floor",
      gaugemin = 0,
      gaugemax = 140,
      unit = "%",
      font = "FONT_XXL",
      textoffsetx = 12,
      arcOffsetY = 4,
      arcThickness = 1,
      startAngle = 225,
      sweep = 270,
      arcbgcolor = "lightgrey",
      title = "Current",
      titlepos = "bottom",
      bgcolor = "transparent",

      thresholds = {
          { value = 30,  fillcolor = "red",    textcolor = "white" },
          { value = 50,  fillcolor = "orange", textcolor = "white" },
          { value = 140, fillcolor = "green",  textcolor = "white" }
      },

      gaugemin = 0,
      gaugemax = 100
  },  
  {
      col = 15, 
      row = 1,
      rowspan = 6,
      colspan = 6,
      type = "gauge",
      subtype = "arcmax",
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
      gaugeorientation = "horizontal",
      fillbgcolor = "grey",
      gaugepadding = 4,
      gaugebelowtitle = true,
      title = "Voltage",
      unit = "V",
      textcolor = "white",
      valuealign = "center",
      titlealign = "center",
      titlepos = "bottom",
      fillcolor = "green",
       textoffsetx = 12,
      arcOffsetY = 4,
      arcThickness = 1,
      startAngle = 225,
      sweep = 270,     
      bgcolor = "transparent",
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
  {
      col = 9, 
      row = 7,
      rowspan = 2,
      colspan = 12,
      type = "gauge",
      subtype = "battery",
      source = "fuel",
      gaugemin = 0,
      gaugemax = 100,
      fillbgcolor = "gray",
      gaugeorientation = "horizontal",
      gaugebelowtitle = true,
      showvalue = true,
      unit = "%",
      textcolor = "black",
      valuealign = "center",
      titlealign = "center",
      titlepos = "bottom",
      titlecolor = "white",
      fillcolor = "green",
      batteryframe = true,
      batteryframethickness = 4,
      bgcolor = "transparent",
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
}


return {
    layout = layout,
    boxes = boxes,
    scheduler = {
        wakeup_interval = 0.25,          -- Interval (seconds) to run wakeup script when display is visible
        wakeup_interval_bg = 5,         -- (optional: run wakeup this often when not visible; set nil/empty to skip)
        paint_interval = 0.5,            -- Interval (seconds) to run paint script when display is visible 
    }    
}
