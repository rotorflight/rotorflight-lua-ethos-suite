--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local PageFiles = {}

PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.bluejay.general)@", script = "esc_basic.lua", image = "basic.jpg"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.bluejay.brake)@", script = "esc_advanced.lua", image = "advanced.jpg"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.bluejay.beacon)@", script = "esc_beacon.lua", image = "other.jpg"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.bluejay.other)@", script = "esc_other.lua", image = "limits.jpg"}

return PageFiles
