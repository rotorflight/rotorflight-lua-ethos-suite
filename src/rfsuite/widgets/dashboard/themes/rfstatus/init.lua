--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local init = {
    name = "RF Status",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "RF Status",
        background = {7, 15, 18}, surface = {13, 28, 32},
        surfaceAlt = {20, 42, 47}, text = {232, 248, 248},
        muted = {130, 166, 168}, accent = {0, 205, 223},
        focus = {57, 228, 118}, warning = {255, 190, 57},
        error = {255, 75, 82}, border = {53, 105, 111}
    },
    standalone = false
}

return init
