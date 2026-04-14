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
    hooksScript = "app/modules/beepers/menu_hooks.lua",
    iconPrefix = "app/modules/beepers/gfx/",
    loaderSpeed = "DEFAULT",
    navButtons = {
        help = true,
        menu = true,
        reload = false,
        save = false,
        tool = false,
    },
    navOptions = {
        defaultSection = "setup",
    },
    pages = {
        {
            image = "configuration.png",
            name = "@i18n(app.modules.beepers.menu_configuration)@",
            script = "configuration.lua",
            shortcutId = "s_beepers_configuration_lua_3d60a90251",
        },
        {
            image = "dshot.png",
            name = "@i18n(app.modules.beepers.menu_dshot)@",
            script = "dshot.lua",
            shortcutId = "s_beepers_dshot_lua_f1e47cbff2",
        },
    },
    scriptPrefix = "beepers/tools/",
    title = "@i18n(app.modules.beepers.name)@",
}
