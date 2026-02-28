--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html

  AUTO-GENERATED FILE - DO NOT EDIT DIRECTLY.
  Edit menu data with: bin/menu/editor/menu_editor.cmd (Windows)
  or: python bin/menu/editor/src/menu_editor.py
  Source of truth: bin/menu/manifest.source.json
  Regenerate with: python bin/menu/generate.py
]] --

return {
    hooksScript = "app/modules/settings/tools/dashboard_hooks.lua",
    iconPrefix = "app/modules/settings/gfx/",
    moduleKey = "settings_dashboard",
    navButtons = {
        help = false,
        menu = true,
        reload = false,
        save = false,
        tool = false,
    },
    navOptions = {
        defaultSection = "system",
        showProgress = true,
    },
    pages = {
        {
            image = "dashboard_theme.png",
            name = "@i18n(app.modules.settings.dashboard_theme)@",
            offline = true,
            script = "dashboard_theme.lua",
            shortcutId = "s_settings_dashboard_dashboard_theme_l_356eb135bd",
        },
        {
            image = "dashboard_settings.png",
            name = "@i18n(app.modules.settings.dashboard_settings)@",
            offline = false,
            script = "dashboard_settings.lua",
            shortcutId = "s_settings_dashboard_dashboard_setting_46c08bc7ee",
        },
    },
    scriptPrefix = "settings/tools/",
    title = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.dashboard)@",
}
