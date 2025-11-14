--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local sections = {}
local tools = {}

sections[#sections + 1] = {title = "@i18n(app.modules.pids.name)@", module = "pids", script = "pids.lua", image = "app/modules/pids/pids.png", offline = false, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.modules.rates.name)@", module = "rates", script = "rates.lua", image = "app/modules/rates/rates.png", offline = false, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.modules.profile_governor.name)@", module = "profile_governor", script = "select.lua", image = "app/modules/profile_governor/governor.png", offline = false, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.modules.profile_tailrotor.name)@", module = "tailrotor", script = "tailrotor.lua", image = "app/modules/tailrotor/tailrotor.png", offline = false, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.menu_section_advanced)@", id = "advanced", image = "app/gfx/advanced.png", loaderspeed = true, offline = false, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.menu_section_hardware)@", id = "hardware", image = "app/gfx/hardware.png", loaderspeed = true, offline = false, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.menu_section_tools)@", id = "tools", image = "app/gfx/tools.png", newline = true, offline = false, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.modules.logs.name)@", module = "logs", script = "logs_dir.lua", image = "app/modules/logs/gfx/logs.png", loaderspeed = true, offline = true, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.modules.settings.name)@", module = "settings", script = "settings.lua", image = "app/modules/settings/settings.png", loaderspeed = true, offline = true, bgtask = false}
sections[#sections + 1] = {title = "@i18n(app.modules.diagnostics.name)@", module = "diagnostics", script = "diagnostics.lua", image = "app/modules/diagnostics/diagnostics.png", loaderspeed = true, bgtask = true, offline = true}

return sections
