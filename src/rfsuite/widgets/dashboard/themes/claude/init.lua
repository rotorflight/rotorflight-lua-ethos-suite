--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name       = "Claude",
    preflight  = "preflight.lua",
    inflight   = "inflight.lua",
    postflight = "postflight.lua",
    configure  = "configure.lua",
    appTheme = {
        name = "Claude",
        background = {8, 14, 24}, surface = {15, 25, 39},
        surfaceAlt = {23, 36, 54}, text = {234, 243, 252},
        muted = {137, 158, 180}, accent = {104, 190, 255},
        focus = {89, 225, 190}, warning = {255, 187, 72},
        error = {255, 91, 110}, border = {72, 101, 130}
    },
    standalone = false,
}

return init
