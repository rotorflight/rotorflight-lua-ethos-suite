--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local PageFiles = {}

PageFiles[#PageFiles + 1] = {title = "Basic", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "Advanced", script = "esc_advanced.lua", image = "advanced.png"}
PageFiles[#PageFiles + 1] = {title = "Input", script = "esc_input.lua", image = "limits.png"}

return PageFiles
