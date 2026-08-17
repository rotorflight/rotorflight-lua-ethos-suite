local init = {
    name = "libertyops250",
    preflight = "preflight.lua",
    inflight = "inflight.lua",
    postflight = "postflight.lua",
    configure = "configure.lua",
    standalone = false,
    minResolution = {x = 784, y = 294},
    appTheme = {
        name = "Liberty Ops 250",
        background = {2, 5, 10},
        surface = {5, 10, 18},
        surfaceAlt = {8, 16, 28},
        text = {238, 243, 252},
        muted = {138, 153, 175},
        accent = {42, 111, 214},
        focus = {83, 210, 104},
        warning = {255, 167, 45},
        error = {227, 58, 66},
        border = {28, 75, 137},
        rail = {
            start = {188, 36, 49},
            middle = {238, 243, 252},
            finish = {42, 111, 214}
        }
    }
}

return init
