-- Dashboard palette metadata used by the configurator theme bridge.
--
-- Keep this registry independent from dashboard theme modules. The app can
-- resolve all shipped and separately-maintained radio themes without loading a
-- dashboard init.lua during paint (or loading a theme that is not installed on
-- this branch). Unknown user themes may still provide an appTheme table in
-- their init.lua; app/theme_bridge.lua probes that file from its throttled
-- wakeup path only.

if package.loaded["rfsuite.app.theme_palettes"] then
  return package.loaded["rfsuite.app.theme_palettes"]
end

local palettes = {
  ["aerc-n"] = {
    name = "AERC Nitro",
    background = {9, 10, 18}, surface = {18, 20, 32}, surfaceAlt = {29, 32, 48},
    text = {239, 241, 255}, muted = {150, 155, 184}, accent = {174, 91, 255},
    focus = {45, 224, 255}, warning = {255, 178, 54}, error = {255, 73, 115}, border = {86, 82, 126},
  },
  aerc = {
    name = "AERC",
    background = {15, 16, 18}, surface = {27, 29, 33}, surfaceAlt = {38, 41, 46},
    text = {243, 244, 246}, muted = {157, 162, 170}, accent = {255, 145, 35},
    focus = {70, 170, 255}, warning = {255, 195, 65}, error = {255, 82, 82}, border = {93, 99, 110},
  },
  claude = {
    name = "Claude",
    background = {8, 14, 24}, surface = {15, 25, 39}, surfaceAlt = {23, 36, 54},
    text = {234, 243, 252}, muted = {137, 158, 180}, accent = {104, 190, 255},
    focus = {89, 225, 190}, warning = {255, 187, 72}, error = {255, 91, 110}, border = {72, 101, 130},
  },
  danielrc = {
    name = "DanielRC",
    background = {5, 12, 14}, surface = {11, 24, 27}, surfaceAlt = {19, 37, 40},
    text = {232, 248, 247}, muted = {132, 166, 166}, accent = {0, 229, 244},
    focus = {52, 235, 70}, warning = {255, 226, 35}, error = {255, 83, 92}, border = {54, 107, 112},
  },
  default = {
    name = "Default",
    background = {18, 20, 24}, surface = {32, 35, 41}, surfaceAlt = {45, 49, 57},
    text = {239, 242, 246}, muted = {153, 161, 172}, accent = {0, 204, 224},
    focus = {70, 211, 129}, warning = {255, 183, 64}, error = {255, 86, 103}, border = {83, 91, 105},
  },
  gismo = {
    name = "Gismo",
    background = {8, 12, 22}, surface = {15, 23, 38}, surfaceAlt = {24, 34, 53},
    text = {233, 242, 255}, muted = {135, 153, 180}, accent = {55, 145, 255},
    focus = {45, 224, 255}, warning = {255, 182, 65}, error = {255, 80, 104}, border = {67, 91, 128},
  },
  -- HeliHUD does not publish an app palette. Preserve native ETHOS colors
  -- instead of inventing a palette that could make its controls unreadable.
  helihud = {name = "HeliHUD", native = true},
  kevd = {
    name = "Kevd",
    background = {15, 13, 8}, surface = {29, 25, 14}, surfaceAlt = {43, 36, 20},
    text = {250, 244, 225}, muted = {175, 161, 124}, accent = {227, 163, 0},
    focus = {90, 215, 120}, warning = {255, 192, 50}, error = {244, 75, 66}, border = {112, 91, 45},
  },
  rfstatus = {
    name = "RF Status",
    background = {7, 15, 18}, surface = {13, 28, 32}, surfaceAlt = {20, 42, 47},
    text = {232, 248, 248}, muted = {130, 166, 168}, accent = {0, 205, 223},
    focus = {57, 228, 118}, warning = {255, 190, 57}, error = {255, 75, 82}, border = {53, 105, 111},
  },
  ["rt-rc-n"] = {
    name = "RT-RC Nitro",
    background = {5, 10, 19}, surface = {11, 21, 35}, surfaceAlt = {18, 34, 52},
    text = {234, 246, 255}, muted = {132, 161, 183}, accent = {0, 220, 255},
    focus = {178, 255, 66}, warning = {255, 168, 45}, error = {255, 67, 105}, border = {52, 98, 132},
  },
  ["rt-rc"] = {
    name = "RT-RC",
    background = {11, 14, 20}, surface = {20, 26, 36}, surfaceAlt = {30, 39, 53},
    text = {236, 242, 250}, muted = {143, 157, 177}, accent = {67, 156, 255},
    focus = {58, 220, 176}, warning = {255, 185, 66}, error = {255, 85, 99}, border = {72, 91, 120},
  },
  ["srb-rc"] = {
    name = "SRB-RC",
    background = {18, 14, 11}, surface = {32, 25, 20}, surfaceAlt = {46, 36, 28},
    text = {248, 241, 232}, muted = {172, 154, 139}, accent = {239, 139, 53},
    focus = {80, 211, 139}, warning = {255, 191, 58}, error = {247, 77, 70}, border = {112, 86, 68},
  },
  timer = {
    name = "Basic Timer",
    background = {11, 15, 17}, surface = {20, 27, 30}, surfaceAlt = {29, 39, 43},
    text = {239, 247, 247}, muted = {146, 165, 166}, accent = {60, 220, 181},
    focus = {88, 230, 118}, warning = {255, 190, 67}, error = {255, 81, 94}, border = {67, 96, 98},
  },

  -- Separately maintained radio themes. Keeping their bridge metadata here
  -- lets this branch remain independent while still composing cleanly with
  -- any one of the theme branches.
  aegis = {
    name = "Aegis",
    background = {7, 11, 16}, surface = {14, 21, 29}, surfaceAlt = {19, 28, 38},
    text = {230, 239, 247}, muted = {132, 151, 168}, accent = {48, 218, 238},
    focus = {75, 224, 149}, warning = {255, 183, 72}, error = {255, 86, 103}, border = {76, 97, 115},
    rail = {start = {48, 218, 238}, middle = {174, 133, 255}, finish = {255, 183, 72}},
  },
  america250 = {
    name = "America 250",
    background = {4, 14, 31}, surface = {8, 24, 47}, surfaceAlt = {12, 34, 61},
    text = {240, 231, 207}, muted = {160, 174, 187}, accent = {240, 231, 207},
    focus = {49, 120, 198}, warning = {216, 170, 78}, error = {184, 48, 49}, border = {68, 91, 116},
    rail = {start = {184, 48, 49}, middle = {240, 231, 207}, finish = {49, 120, 198}},
  },
  libertyops250 = {
    name = "Liberty Ops 250",
    background = {2, 5, 10}, surface = {5, 10, 18}, surfaceAlt = {8, 16, 28},
    text = {238, 243, 252}, muted = {138, 153, 175}, accent = {42, 111, 214},
    focus = {83, 210, 104}, warning = {255, 167, 45}, error = {227, 58, 66}, border = {28, 75, 137},
    rail = {start = {188, 36, 49}, middle = {238, 243, 252}, finish = {42, 111, 214}},
  },
  mwrc = {
    name = "MWRC",
    background = {5, 8, 14}, surface = {12, 18, 28}, surfaceAlt = {30, 45, 60},
    text = {230, 240, 255}, muted = {120, 142, 164}, accent = {0, 240, 255},
    focus = {57, 255, 20}, warning = {255, 170, 0}, error = {255, 0, 60}, border = {64, 86, 110},
    rail = {start = {0, 240, 255}, middle = {57, 255, 20}, finish = {255, 170, 0}},
  },
  singularity = {
    name = "Singularity",
    background = {3, 5, 12}, surface = {8, 12, 24}, surfaceAlt = {13, 18, 34},
    text = {228, 240, 255}, muted = {122, 147, 177}, accent = {170, 97, 255},
    focus = {58, 236, 255}, warning = {255, 190, 70}, error = {255, 72, 110}, border = {75, 101, 140},
    rail = {start = {58, 236, 255}, middle = {170, 97, 255}, finish = {255, 72, 160}},
  },
  zafira = {
    name = "Zafira",
    background = {34, 26, 42}, surface = {45, 34, 54}, surfaceAlt = {57, 42, 68},
    text = {246, 239, 255}, muted = {190, 166, 199}, accent = {255, 199, 91},
    focus = {58, 238, 216}, warning = {255, 166, 62}, error = {255, 74, 96}, border = {151, 107, 160},
    rail = {start = {255, 199, 91}, middle = {58, 238, 216}, finish = {255, 74, 180}},
  },
}

local registry = {}

function registry.get(themeId)
  return palettes[themeId]
end

package.loaded["rfsuite.app.theme_palettes"] = registry
return registry
