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
        showProgress = true,
    },
    pages = {
        {
            image = "filters/filters.png",
            name = "@i18n(app.modules.filters.name)@",
            order = 1,
            script = "filters/filters.lua",
            shortcutId = "s_advanced_menu_filters_filters_lua_f1de87c4bd",
        },
        {
            apiversion = { 12, 0, 6 },
            image = "profile_pidcontroller/pids-controller.png",
            name = "@i18n(app.modules.profile_pidcontroller.name)@",
            order = 2,
            script = "profile_pidcontroller/pidcontroller.lua",
            shortcutId = "s_advanced_menu_profile_pidcontroller_d88ea3ba97",
        },
        {
            apiversion = { 12, 0, 6 },
            image = "profile_pidbandwidth/pids-bandwidth.png",
            name = "@i18n(app.modules.profile_pidbandwidth.name)@",
            order = 3,
            script = "profile_pidbandwidth/pidbandwidth.lua",
            shortcutId = "s_advanced_menu_profile_pidbandwidth_p_650df8805e",
        },
        {
            apiversion = { 12, 0, 6 },
            image = "profile_autolevel/autolevel.png",
            name = "@i18n(app.modules.profile_autolevel.name)@",
            order = 4,
            script = "profile_autolevel/autolevel.lua",
            shortcutId = "s_advanced_menu_profile_autolevel_auto_d9832fb3eb",
        },
        {
            apiversion = { 12, 0, 6 },
            image = "profile_mainrotor/mainrotor.png",
            name = "@i18n(app.modules.profile_mainrotor.name)@",
            order = 5,
            script = "profile_mainrotor/mainrotor.lua",
            shortcutId = "s_advanced_menu_profile_mainrotor_main_99724a655d",
        },
        {
            apiversion = { 12, 0, 6 },
            image = "profile_tailrotor/tailrotor.png",
            name = "@i18n(app.modules.profile_tailrotor.name)@",
            order = 6,
            script = "profile_tailrotor/tailrotor.lua",
            shortcutId = "s_advanced_menu_profile_tailrotor_tail_9cd82ec0d9",
        },
        {
            apiversion = { 12, 0, 6 },
            image = "profile_rescue/rescue.png",
            name = "@i18n(app.modules.profile_rescue.name)@",
            order = 7,
            script = "profile_rescue/rescue.lua",
            shortcutId = "s_advanced_menu_profile_rescue_rescue_3bb5c29dca",
        },
        {
            apiversion = { 12, 0, 6 },
            image = "rates_advanced/rates.png",
            name = "@i18n(app.modules.rates_advanced.name)@",
            order = 8,
            script = "rates_advanced/rates_advanced.lua",
            shortcutId = "s_advanced_menu_rates_advanced_rates_a_ef4795e385",
        },
    },
    scriptPrefix = "app/modules/",
    title = "@i18n(app.menu_section_advanced)@",
}
