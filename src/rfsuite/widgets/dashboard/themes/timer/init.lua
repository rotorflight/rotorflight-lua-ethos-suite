--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "Basic Timer",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    appTheme = {
        name = "Basic Timer",
        background = {11, 15, 17}, surface = {20, 27, 30},
        surfaceAlt = {29, 39, 43}, text = {239, 247, 247},
        muted = {146, 165, 166}, accent = {60, 220, 181},
        focus = {88, 230, 118}, warning = {255, 190, 67},
        error = {255, 81, 94}, border = {67, 96, 98}
    },
    standalone = false
}

return init
