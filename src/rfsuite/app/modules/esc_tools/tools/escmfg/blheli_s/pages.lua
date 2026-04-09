--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local PageFiles = {}

PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.blheli_s.basic)@", script = "esc_basic.lua", image = "basic.jpg"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.blheli_s.advanced)@", script = "esc_advanced.lua", image = "advanced.jpg"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.blheli_s.input)@", script = "esc_input.lua", image = "limits.jpg"}

return PageFiles
