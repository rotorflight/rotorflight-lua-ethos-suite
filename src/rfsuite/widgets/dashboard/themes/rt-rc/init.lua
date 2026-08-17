--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "RT-RC",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "RT-RC",
        background = {11, 14, 20}, surface = {20, 26, 36},
        surfaceAlt = {30, 39, 53}, text = {236, 242, 250},
        muted = {143, 157, 177}, accent = {67, 156, 255},
        focus = {58, 220, 176}, warning = {255, 185, 66},
        error = {255, 85, 99}, border = {72, 91, 120}
    },
    standalone = false
}

return init
