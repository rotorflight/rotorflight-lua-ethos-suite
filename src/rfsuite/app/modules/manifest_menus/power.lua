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
    iconPrefix = "app/modules/power/gfx/",
    loaderSpeed = 0.08,
    navButtons = {
        help = false,
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
            image = "battery.png",
            name = "@i18n(app.modules.power.battery_name)@",
            script = "battery.lua",
            shortcutId = "s_power_battery_lua_5a48ba2cab",
        },
        {
            image = "alerts.png",
            name = "@i18n(app.modules.power.alert_name)@",
            script = "alerts.lua",
            shortcutId = "s_power_alerts_lua_9fd7dbdc4d",
        },
        {
            image = "source.png",
            name = "@i18n(app.modules.power.source_name)@",
            script = "source.lua",
            shortcutId = "s_power_source_lua_6d24f8cd57",
        },
    },
    scriptPrefix = "power/tools/",
    title = "@i18n(app.modules.power.name)@",
}
