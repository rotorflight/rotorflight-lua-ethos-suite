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
        {image = "activelook_preflight.png", name = "@i18n(app.modules.settings.activelook_preflight)@", offline = true, script = "preflight.lua"},
        {image = "activelook_inflight.png", name = "@i18n(app.modules.settings.activelook_inflight)@", offline = true, script = "inflight.lua"},
        {image = "activelook_postflight.png", name = "@i18n(app.modules.settings.activelook_postflight)@", offline = true, script = "postflight.lua"},
        {image = "activelook_settings.png", name = "@i18n(app.modules.settings.activelook_settings)@", offline = true, script = "settings.lua"}
    }
})
