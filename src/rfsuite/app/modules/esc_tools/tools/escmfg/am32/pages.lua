--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local PageFiles = {}

-- ESC pages.
PageFiles[#PageFiles + 1] = {title = "Basic", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "Advanced", script = "esc_advanced.lua", image = "advanced.png"}
PageFiles[#PageFiles + 1] = {title = "Limits", script = "esc_limits.lua", image = "advanced.png"}

return PageFiles
