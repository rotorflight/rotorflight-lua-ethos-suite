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
    hooksScript = "app/modules/profile_governor/menu_hooks.lua",
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
        showProgress = true,
    },
    pages = {
        {
            image = "general.png",
            name = "@i18n(app.modules.governor.menu_general)@",
            script = "general.lua",
            shortcutId = "s_profile_governor_general_lua_3a27cf6764",
        },
        {
            image = "flags.png",
            name = "@i18n(app.modules.governor.menu_flags)@",
            script = "flags.lua",
            shortcutId = "s_profile_governor_flags_lua_3992e9f64d",
        },
    },
    scriptPrefix = "profile_governor/tools/",
    title = "@i18n(app.modules.profile_governor.name)@",
}
