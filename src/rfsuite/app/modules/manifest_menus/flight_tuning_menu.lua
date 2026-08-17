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
    loaderSpeed = "DEFAULT",
    navOptions = {
        showProgress = true,
    },
    pages = {
        {
            image = "pids/pids.png",
            name = "PIDs",
            order = 1,
            script = "pids/pids.lua",
            shortcutId = "s_flight_tuning_menu_pids_pids_lua_e97a40faab",
        },
        {
            image = "rates/rates.png",
            name = "Rates",
            order = 2,
            script = "rates/rates.lua",
            shortcutId = "s_flight_tuning_menu_rates_rates_lua_853c5751ea",
        },
        {
            image = "profile_governor/governor.png",
            name = "Governor",
            order = 3,
            script = "profile_governor/governor.lua",
            script_by_mspversion = {
                {
                    op = ">=",
                    script = "profile_governor/governor.lua",
                    ver = { 12, 0, 9 },
                },
                {
                    op = "<",
                    script = "profile_governor/governor_legacy.lua",
                    ver = { 12, 0, 9 },
                },
            },
            script_default = "profile_governor/governor_legacy.lua",
            shortcutId = "s_flight_tuning_menu_profile_governor_2361300e05",
        },
        {
            image = "app/gfx/advanced.png",
            menuId = "advanced_menu",
            name = "Advanced",
            order = 4,
            shortcutId = "s_flight_tuning_menu_advanced_menu_2abad2cdec",
        },
    },
    scriptPrefix = "app/modules/",
    title = "Flight Tuning",
}
