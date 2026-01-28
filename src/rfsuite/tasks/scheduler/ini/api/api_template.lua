--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local API_NAME = "TEST_API"

local API_STRUCTURE = {{field = "pitch", min = -300, max = 300, default = 0, unit = "°"}, {field = "roll", min = -300, max = 300, default = 0, unit = "°"}}

return {API_STRUCTURE = API_STRUCTURE}
