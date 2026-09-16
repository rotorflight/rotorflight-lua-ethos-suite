--[[
  Aegis dashboard theme for Rotorflight ETHOS Suite
  Designed for the FrSky X20 Pro (800x480)
  GPLv3
]] --

return {
    name = "Aegis",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    appTheme = {
        name = "Aegis", background = {7, 11, 16}, surface = {14, 21, 29}, surfaceAlt = {19, 28, 38},
        text = {230, 239, 247}, muted = {132, 151, 168}, accent = {48, 218, 238},
        focus = {75, 224, 149}, warning = {255, 183, 72}, error = {255, 86, 103}, border = {76, 97, 115},
        rail = {
            start = {48, 218, 238},
            middle = {174, 133, 255},
            finish = {255, 183, 72}
        }
    },
    standalone = false,
    minResolution = {x = 784, y = 294}
}
