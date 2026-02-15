--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local submenuBuilder = assert(loadfile("app/lib/submenu_builder.lua"))()

return submenuBuilder.create({
    moduleKey = "hardware_menu",
    hooksScript = "app/modules/hardware/menu_hooks.lua",
    scriptPrefix = "app/modules/",
    iconPrefix = "",
    navOptions = {showProgress = true}
})

