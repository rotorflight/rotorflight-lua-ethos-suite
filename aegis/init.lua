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
    standalone = false,
    minResolution = {x = 784, y = 294}
}
