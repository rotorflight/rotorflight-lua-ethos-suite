--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "Default",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Default",
        background = {18, 20, 24}, surface = {32, 35, 41},
        surfaceAlt = {45, 49, 57}, text = {239, 242, 246},
        muted = {153, 161, 172}, accent = {0, 204, 224},
        focus = {70, 211, 129}, warning = {255, 183, 64},
        error = {255, 86, 103}, border = {83, 91, 105}
    },
    standalone = false
}

return init
