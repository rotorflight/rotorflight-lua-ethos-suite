--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --
 
return {
  [1] = {
    name = "Rotorflight Dashboard",
    script = "dashboard.lua",
    varname = "dashboard",
    key = "rf2sdh",
    folder = "dashboard",
    feature = "dashboard",
    type = "widget",
  },
  [2] = {
    name = "Rotorflight Toolbox",
    script = "toolbox.lua",
    varname = "rftlbx",
    key = "rftlbx",
    folder = "toolbox",
    feature = "toolbox",
    type = "widget",    
  },
  [3] = {
    name = "Rotorflight ActiveLook",
    script = "activelook.lua",
    varname = "rfactivelook",
    key = "rfalk",
    folder = "activelook",
    feature = "activelook",
    type = "glasses",    
  },
}
