--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local init = {title = "@i18n(app.modules.battery.name)@", section = "hardware", script = "battery.lua", image = "battery.png", order = 10, ethosversion = {1, 6, 2}}

return init
