--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local init = {
    name = "SRB-RC",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "SRB-RC",
        background = {18, 14, 11}, surface = {32, 25, 20},
        surfaceAlt = {46, 36, 28}, text = {248, 241, 232},
        muted = {172, 154, 139}, accent = {239, 139, 53},
        focus = {80, 211, 139}, warning = {255, 191, 58},
        error = {247, 77, 70}, border = {112, 86, 68}
    },
    standalone = false
}

return init
