--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local init = {
    title = "@i18n(app.modules.ports.name)@",
    section = "hardware",
    script = "ports.lua",
    image = "ports.png",
    order = 8,
    loaderspeed = 0.08,
    ethosversion = {1, 6, 2}
}

return init
