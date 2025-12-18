--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {title = "@i18n(app.modules.fbusout.name)@", section = "hardware", script = "fbusout.lua", image = "fbusout.png", order = 3, loaderspeed = true, ethosversion = {1, 6, 2}, mspversion = 12.09}

return init
