--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "Gismo",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Gismo",
        background = {8, 12, 22}, surface = {15, 23, 38},
        surfaceAlt = {24, 34, 53}, text = {233, 242, 255},
        muted = {135, 153, 180}, accent = {55, 145, 255},
        focus = {45, 224, 255}, warning = {255, 182, 65},
        error = {255, 80, 104}, border = {67, 91, 128}
    },
    standalone = false
}

return init
