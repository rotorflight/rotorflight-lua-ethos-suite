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
    hooksScript = "app/modules/rates_advanced/menu_hooks.lua",
    iconPrefix = "app/modules/rates_advanced/gfx/",
    loaderSpeed = "DEFAULT",
    navButtons = {
        help = false,
        menu = true,
        reload = false,
        save = false,
        tool = false,
    },
    navOptions = {
        defaultSection = "flight_tuning",
        showProgress = true,
    },
    pages = {
        {
            image = "advanced.png",
            name = "Advanced",
            script = "advanced.lua",
            shortcutId = "s_rates_advanced_advanced_lua_5673f8caee",
        },
        {
            image = "cyclic_behaviour.png",
            name = "Cyclic Behaviour",
            script = "cyclic_behaviour.lua",
            shortcutId = "s_rates_advanced_cyclic_behaviour_lua_df5de615f1",
        },
        {
            image = "table.png",
            name = "Rate Table",
            script = "table.lua",
            shortcutId = "s_rates_advanced_table_lua_7e2b9c5584",
        },
    },
    scriptPrefix = "rates_advanced/tools/",
    title = "Rates",
}
