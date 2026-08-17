--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "RT-RC Nitro",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "RT-RC Nitro",
        background = {5, 10, 19}, surface = {11, 21, 35},
        surfaceAlt = {18, 34, 52}, text = {234, 246, 255},
        muted = {132, 161, 183}, accent = {0, 220, 255},
        focus = {178, 255, 66}, warning = {255, 168, 45},
        error = {255, 67, 105}, border = {52, 98, 132}
    },
    standalone = false
}

return init
