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
    sections = {
        {
            id = "configuration",
            sections = {
                {
                    bgtask = true,
                    ethosversion = { 1, 6, 2 },
                    id = "flight_tuning",
                    image = "app/gfx/flight_tuning.png",
                    loaderspeed = "FAST",
                    menuId = "flight_tuning_menu",
                    title = "@i18n(app.menu_section_flight_tuning)@",
                },
                {
                    bgtask = true,
                    ethosversion = { 1, 6, 2 },
                    id = "setup",
                    image = "app/gfx/hardware.png",
                    loaderspeed = "FAST",
                    menuId = "setup_menu",
                    title = "@i18n(app.modules.hardware_setup.name)@",
                },
            },
            title = "@i18n(app.header_configuration)@",
        },
        {
            id = "system",
            sections = {
                {
                    ethosversion = { 1, 6, 2 },
                    image = "app/gfx/tools.png",
                    menuId = "tools_menu",
                    offline = true,
                    title = "@i18n(app.menu_section_tools)@",
                },
                {
                    bgtask = true,
                    ethosversion = { 1, 6, 2 },
                    image = "app/modules/logs/gfx/logs.png",
                    loaderspeed = "FAST",
                    module = "logs",
                    offline = true,
                    script = "logs_dir.lua",
                    title = "@i18n(app.modules.logs.name)@",
                },
                {
                    bgtask = true,
                    ethosversion = { 1, 6, 2 },
                    image = "app/modules/settings/settings.png",
                    menuId = "settings_admin",
                    offline = true,
                    title = "@i18n(app.modules.settings.name)@",
                },
                {
                    bgtask = true,
                    developer = true,
                    ethosversion = { 1, 6, 2 },
                    image = "app/modules/developer/developer.png",
                    module = "developer",
                    offline = true,
                    script = "developer.lua",
                    title = "@i18n(app.modules.settings.txt_developer)@",
                },
            },
            title = "@i18n(app.header_system)@",
        },
    },
}
