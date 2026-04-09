--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local PageFiles = {}

PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.scorp.basic)@", script = "esc_basic.lua", image = "basic.jpg"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.scorp.limits)@", script = "esc_protection.lua", image = "limits.jpg"}
PageFiles[#PageFiles + 1] = {title = "@i18n(app.modules.esc_tools.mfg.scorp.advanced)@", script = "esc_advanced.lua", image = "advanced.jpg"}

return PageFiles
