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
    hooksScript = "app/modules/blackbox/menu_hooks.lua",
    iconPrefix = "app/modules/blackbox/gfx/",
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
            name = "@i18n(app.modules.blackbox.menu_configuration)@",
            script = "configuration.lua",
            shortcutId = "s_blackbox_configuration_lua_1b07855e2c",
        },
        {
            image = "logging.png",
            name = "@i18n(app.modules.blackbox.menu_logging)@",
            script = "logging.lua",
            shortcutId = "s_blackbox_logging_lua_6216852e49",
        },
        {
            image = "status.png",
            name = "@i18n(app.modules.blackbox.menu_status)@",
            script = "status.lua",
            shortcutId = "s_blackbox_status_lua_6d398bae79",
        },
    },
    scriptPrefix = "blackbox/tools/",
    title = "@i18n(app.modules.blackbox.name)@",
}
