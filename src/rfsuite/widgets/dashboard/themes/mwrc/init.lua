--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local init = {
    name = "mwrc",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    standalone = false,
    minResolution = {x = 784, y = 294},
    logo = {dark = "gfx/rfsuite-dark.png", light = "gfx/rfsuite-light.png"}
}

return init
