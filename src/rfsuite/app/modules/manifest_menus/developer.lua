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
    childTitlePrefix = "@i18n(app.modules.settings.txt_developer)@",
    loaderSpeed = 0.08,
    navButtons = {
        help = false,
        menu = true,
        reload = false,
        save = false,
        tool = false,
    },
    pages = {
        {
            bgtask = true,
            image = "app/modules/developer/gfx/msp_speed.png",
            name = "@i18n(app.modules.msp_speed.name)@",
            offline = false,
            script = "developer/tools/msp_speed.lua",
            shortcutId = "s_developer_developer_tools_msp_speed_2a349a7d8c",
        },
        {
            bgtask = true,
            image = "app/modules/developer/gfx/api_tester.png",
            name = "@i18n(app.modules.api_tester.name)@",
            offline = false,
            script = "developer/tools/api_tester.lua",
            shortcutId = "s_developer_developer_tools_api_tester_41baf630d2",
        },
        {
            bgtask = true,
            image = "app/modules/developer/gfx/msp_exp.png",
            name = "@i18n(app.modules.msp_exp.name)@",
            offline = false,
            script = "developer/tools/msp_exp.lua",
            shortcutId = "s_developer_developer_tools_msp_exp_lu_871dbba7c4",
        },
        {
            bgtask = true,
            image = "app/modules/developer/gfx/settings.png",
            name = "@i18n(app.modules.settings.name)@",
            offline = true,
            script = "settings/tools/development.lua",
            shortcutId = "s_developer_settings_tools_development_44d17e37da",
        },
    },
    title = "@i18n(app.modules.settings.txt_developer)@",
}
