--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local submenuBuilder = assert(loadfile("app/lib/submenu_builder.lua"))()

return submenuBuilder.create({
    moduleKey = "settings_admin",
    scriptPrefix = "settings/tools/",
    iconPrefix = "app/modules/settings/gfx/",
    hooksScript = "app/modules/settings/admin_hooks.lua"
})
