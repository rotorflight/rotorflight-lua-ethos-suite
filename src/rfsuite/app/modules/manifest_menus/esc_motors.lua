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
    hooksScript = "app/modules/esc_motors/menu_hooks.lua",
    iconPrefix = "app/modules/esc_motors/gfx/",
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
        showProgress = true,
    },
    pages = {
        {
            image = "throttle.png",
            name = "@i18n(app.modules.esc_motors.throttle)@",
            script = "throttle.lua",
            shortcutId = "s_esc_motors_throttle_lua_17f21fa300",
        },
        {
            image = "telemetry.png",
            name = "@i18n(app.modules.esc_motors.telemetry)@",
            script = "telemetry.lua",
            shortcutId = "s_esc_motors_telemetry_lua_a9d9e2a50a",
        },
        {
            image = "rpm.png",
            name = "@i18n(app.modules.esc_motors.rpm)@",
            script = "rpm.lua",
            shortcutId = "s_esc_motors_rpm_lua_19b6337da0",
        },
        {
            image = "app/modules/esc_tools/esc.png",
            loaderspeed = false,
            name = "@i18n(app.modules.esc_tools.name)@",
            offline = false,
            script = "app/modules/esc_tools/tools/esc.lua",
            shortcutId = "s_powertrain_menu_esc_tools_tools_esc_0ded099fe9",
        },
    },
    scriptPrefix = "esc_motors/tools/",
    title = "@i18n(app.modules.esc_motors.name)@",
}
