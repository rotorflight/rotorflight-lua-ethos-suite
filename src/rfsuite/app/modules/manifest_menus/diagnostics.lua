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
    iconPrefix = "app/modules/diagnostics/gfx/",
    loaderSpeed = 0.08,
    navOptions = {
        defaultSection = "system",
    },
    pages = {
        {
            bgtask = false,
            image = "rfstatus.png",
            name = "@i18n(app.modules.rfstatus.name)@",
            offline = false,
            script = "rfstatus.lua",
            shortcutId = "s_diagnostics_rfstatus_lua_ac6fe96c58",
        },
        {
            bgtask = true,
            image = "sensors.png",
            name = "@i18n(app.modules.validate_sensors.name)@",
            offline = true,
            script = "sensors.lua",
            shortcutId = "s_diagnostics_sensors_lua_0010694864",
        },
        {
            bgtask = true,
            image = "fblsensors.png",
            name = "@i18n(app.modules.fblsensors.name)@",
            offline = false,
            script = "fblsensors.lua",
            shortcutId = "s_diagnostics_fblsensors_lua_05321e9f3c",
        },
        {
            bgtask = true,
            image = "fblstatus.png",
            name = "@i18n(app.modules.fblstatus.name)@",
            offline = false,
            script = "fblstatus.lua",
            shortcutId = "s_diagnostics_fblstatus_lua_d9afde0a7c",
        },
        {
            bgtask = true,
            image = "info.png",
            name = "@i18n(app.modules.info.name)@",
            offline = true,
            script = "info.lua",
            shortcutId = "s_diagnostics_info_lua_5025a3d5b5",
        },
    },
    scriptPrefix = "diagnostics/tools/",
    title = "@i18n(app.modules.diagnostics.name)@",
}
