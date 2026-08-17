--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local PageFiles = {}

PageFiles[#PageFiles + 1] = {title = "General", script = "esc_basic.lua", image = "basic.png"}
PageFiles[#PageFiles + 1] = {title = "Brake", script = "esc_advanced.lua", image = "advanced.png"}
PageFiles[#PageFiles + 1] = {title = "Beacon", script = "esc_beacon.lua", image = "other.png"}
PageFiles[#PageFiles + 1] = {title = "Other", script = "esc_other.lua", image = "limits.png"}

return PageFiles
