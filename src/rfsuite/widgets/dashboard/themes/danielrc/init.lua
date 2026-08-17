--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    name = "DanielRC",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    appTheme = {
        name = "DanielRC",
        background = {5, 12, 14}, surface = {11, 24, 27},
        surfaceAlt = {19, 37, 40}, text = {232, 248, 247},
        muted = {132, 166, 166}, accent = {0, 229, 244},
        focus = {52, 235, 70}, warning = {255, 226, 35},
        error = {255, 83, 92}, border = {54, 107, 112}
    },
    standalone = false
}
