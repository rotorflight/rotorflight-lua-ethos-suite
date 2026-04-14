--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local submenuBuilder = assert(loadfile("app/lib/submenu_builder.lua"))()

return submenuBuilder.create({
    moduleKey = "settings_activelook",
    title = "ActiveLook",
    iconPrefix = "app/modules/settings/gfx/",
    scriptPrefix = "settings/activelook/",
    navOptions = {defaultSection = "system", showProgress = true},
    pages = {
        {image = "activelook_preflight.png", name = "Preflight", offline = true, script = "preflight.lua"},
        {image = "activelook_inflight.png", name = "Inflight", offline = true, script = "inflight.lua"},
        {image = "activelook_postflight.png", name = "Postflight", offline = true, script = "postflight.lua"},
        {image = "activelook_settings.png", name = "Settings", offline = true, script = "settings.lua"}
    }
})
