--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "Kevd",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Kevd",
        background = {15, 13, 8}, surface = {29, 25, 14},
        surfaceAlt = {43, 36, 20}, text = {250, 244, 225},
        muted = {175, 161, 124}, accent = {227, 163, 0},
        focus = {90, 215, 120}, warning = {255, 192, 50},
        error = {244, 75, 66}, border = {112, 91, 45}
    },
    standalone = false,
    minResolution = {x = 784, y = 294},
    logo = {dark = "gfx/rfsuite-dark.png", light = "gfx/rfsuite-light.png"}
}

return init
