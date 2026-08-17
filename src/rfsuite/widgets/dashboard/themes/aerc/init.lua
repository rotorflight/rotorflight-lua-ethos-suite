--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "AERC",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "AERC",
        background = {15, 16, 18}, surface = {27, 29, 33},
        surfaceAlt = {38, 41, 46}, text = {243, 244, 246},
        muted = {157, 162, 170}, accent = {255, 145, 35},
        focus = {70, 170, 255}, warning = {255, 195, 65},
        error = {255, 82, 82}, border = {93, 99, 110}
    },
    standalone = false
}

return init
