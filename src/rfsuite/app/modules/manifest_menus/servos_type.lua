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
    hooksScript = "app/modules/servos/menu_hooks.lua",
    iconPrefix = "app/modules/servos/gfx/",
    loaderSpeed = "DEFAULT",
    moduleKey = "servos_type",
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
            image = "pwm.png",
            name = "@i18n(app.modules.servos.pwm)@",
            script = "pwm.lua",
            shortcutId = "s_servos_type_pwm_lua_401567fa69",
        },
        {
            image = "bus.png",
            name = "@i18n(app.modules.servos.bus)@",
            script = "bus.lua",
            shortcutId = "s_servos_type_bus_lua_a5236c586f",
        },
    },
    scriptPrefix = "servos/tools/",
    title = "@i18n(app.modules.servos.name)@",
}
