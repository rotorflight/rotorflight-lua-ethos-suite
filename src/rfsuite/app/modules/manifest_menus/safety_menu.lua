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
    iconPrefix = "app/modules/",
    loaderSpeed = "FAST",
    navOptions = {
        defaultSection = "setup",
        showProgress = true,
    },
    pages = {
        {
            image = "modes/modes.png",
            loaderspeed = 0.05,
            name = "@i18n(app.modules.modes.name)@",
            order = 1,
            script = "modes/modes.lua",
            shortcutId = "s_safety_menu_modes_modes_lua_4bfa50db9c",
        },
        {
            image = "adjustments/adjustments.png",
            loaderspeed = 0.1,
            name = "@i18n(app.modules.adjustments.name)@",
            order = 2,
            script = "adjustments/adjustments.lua",
            shortcutId = "s_safety_menu_adjustments_adjustments_1aa898354c",
        },
        {
            image = "failsafe/failsafe.png",
            name = "@i18n(app.modules.failsafe.name)@",
            order = 3,
            script = "failsafe/failsafe.lua",
            shortcutId = "s_safety_menu_failsafe_failsafe_lua_5033612baf",
        },
        {
            image = "beepers/beepers.png",
            menuId = "beepers",
            name = "@i18n(app.modules.beepers.name)@",
            order = 4,
            shortcutId = "s_safety_menu_beepers_7440548a09",
        },
        {
            image = "blackbox/blackbox.png",
            menuId = "blackbox",
            name = "@i18n(app.modules.blackbox.name)@",
            order = 5,
            shortcutId = "s_safety_menu_blackbox_91e70d8f9f",
        },
        {
            image = "stats/stats.png",
            name = "@i18n(app.modules.stats.name)@",
            order = 6,
            script = "stats/stats.lua",
            shortcutId = "s_safety_menu_stats_stats_lua_6e4a1dfd3e",
        },
    },
    scriptPrefix = "app/modules/",
    title = "@i18n(app.menu_section_controls)@",
}
