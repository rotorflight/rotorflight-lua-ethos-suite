--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "AERC Nitro",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "AERC Nitro",
        background = {9, 10, 18}, surface = {18, 20, 32},
        surfaceAlt = {29, 32, 48}, text = {239, 241, 255},
        muted = {150, 155, 184}, accent = {174, 91, 255},
        focus = {45, 224, 255}, warning = {255, 178, 54},
        error = {255, 73, 115}, border = {86, 82, 126}
    },
    standalone = false
}

return init
