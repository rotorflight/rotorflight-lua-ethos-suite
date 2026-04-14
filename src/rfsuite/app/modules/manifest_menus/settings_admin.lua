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
    iconPrefix = "app/modules/settings/gfx/",
    loaderSpeed = 0.08,
    navButtons = {
        help = false,
        menu = true,
        reload = false,
        save = false,
        tool = false,
    },
    navOptions = {
        defaultSection = "system",
        showProgress = true,
    },
    pages = {
        {
            image = "general.png",
            name = "@i18n(app.modules.settings.txt_general)@",
            offline = true,
            script = "tools/general.lua",
            shortcutId = "s_settings_admin_tools_general_lua_37954a091f",
        },
        {
            image = "shortcuts.png",
            name = "@i18n(app.modules.settings.shortcuts)@",
            offline = true,
            script = "tools/shortcuts.lua",
            shortcutId = "s_settings_admin_tools_shortcuts_lua_7ef1a52bf9",
        },
        {
            image = "dashboard.png",
            name = "@i18n(app.modules.settings.dashboard)@",
            offline = true,
            script = "tools/dashboard.lua",
            shortcutId = "s_settings_admin_tools_dashboard_lua_949703e179",
        },
        {
            ethosversion = { 1, 7, 0 },
            image = "activelook.png",
            name = "ActiveLook",
            offline = true,
            script = "activelook.lua",
            shortcutId = "s_settings_admin_activelook_lua_cac11316fe",
        },
        {
            image = "localizations.png",
            name = "@i18n(app.modules.settings.localizations)@",
            offline = true,
            script = "tools/localizations.lua",
            shortcutId = "s_settings_admin_tools_localizations_l_bfcda87566",
        },
        {
            image = "audio.png",
            name = "@i18n(app.modules.settings.audio)@",
            offline = true,
            script = "tools/audio.lua",
            shortcutId = "s_settings_admin_tools_audio_lua_54f65112f1",
        },
    },
    scriptPrefix = "settings/",
    title = "@i18n(app.modules.settings.name)@",
}
