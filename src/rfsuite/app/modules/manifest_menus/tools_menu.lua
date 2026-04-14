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
    navOptions = {
        defaultSection = "system",
        showProgress = true,
    },
    pages = {
        {
            apiversion = { 12, 0, 6 },
            disabled = true,
            image = "copyprofiles/copy.png",
            name = "@i18n(app.modules.copyprofiles.name)@",
            offline = false,
            order = 1,
            script = "copyprofiles/copyprofiles.lua",
            shortcutId = "s_tools_menu_copyprofiles_copyprofiles_020f84c51f",
        },
        {
            apiversion = { 12, 0, 6 },
            image = "profile_select/select_profile.png",
            name = "@i18n(app.modules.profile_select.name)@",
            offline = false,
            order = 2,
            script = "profile_select/select_profile.lua",
            shortcutId = "s_tools_menu_profile_select_select_pro_b62834ef6e",
        },
        {
            image = "diagnostics/diagnostics.png",
            menuId = "diagnostics",
            name = "@i18n(app.modules.diagnostics.name)@",
            offline = true,
            order = 3,
            shortcutId = "s_tools_menu_diagnostics_7095acfa6e",
        },
    },
    scriptPrefix = "app/modules/",
    title = "@i18n(app.menu_section_tools)@",
}
