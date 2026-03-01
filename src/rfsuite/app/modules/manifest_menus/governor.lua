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
    hooksScript = "app/modules/governor/menu_hooks.lua",
    iconPrefix = "app/modules/governor/gfx/",
    loaderSpeed = "DEFAULT",
    navButtons = {
        help = false,
        menu = true,
        reload = false,
        save = false,
        tool = false,
    },
    navOptions = {
        defaultSection = "setup",
        showProgress = true,
    },
    pages = {
        {
            image = "general.png",
            name = "@i18n(app.modules.governor.menu_general)@",
            script = "general.lua",
            shortcutId = "s_governor_general_lua_bb876f329d",
        },
        {
            image = "time.png",
            name = "@i18n(app.modules.governor.menu_time)@",
            script = "time.lua",
            shortcutId = "s_governor_time_lua_3fa58c3610",
        },
        {
            image = "filters.png",
            name = "@i18n(app.modules.governor.menu_filters)@",
            script = "filters.lua",
            shortcutId = "s_governor_filters_lua_258e16a592",
        },
        {
            image = "curves.png",
            name = "@i18n(app.modules.governor.menu_curves)@",
            script = "curves.lua",
            shortcutId = "s_governor_curves_lua_a8f9b2b504",
        },
    },
    scriptPrefix = "governor/tools/",
    title = "@i18n(app.modules.governor.name)@",
}
