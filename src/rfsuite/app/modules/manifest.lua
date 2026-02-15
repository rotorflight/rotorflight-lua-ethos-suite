--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- Module-backed menu manifest.
-- Section entries are shown in the main menu and resolve to module scripts.
-- Submenus are implemented in dedicated `.../menu.lua` + `.../menu_hooks.lua` modules.

local GOV_RULES = {
    {">=", "12.09", "governor.lua", loaderspeed = "FAST"},
    {"<", "12.09", "governor_legacy.lua", loaderspeed = "SLOW"}
}

return {
    sections = {
        {
            title = "@i18n(app.modules.pids.name)@",
            module = "pids",
            script = "pids.lua",
            image = "app/modules/pids/pids.png",
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.modules.rates.name)@",
            module = "rates",
            script = "rates.lua",
            image = "app/modules/rates/rates.png",
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.modules.profile_governor.name)@",
            module = "profile_governor",
            script = "governor.lua",
            image = "app/modules/profile_governor/governor.png",
            script_by_mspversion = GOV_RULES,
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.modules.profile_tailrotor.name)@",
            module = "tailrotor",
            script = "tailrotor.lua",
            image = "app/modules/tailrotor/tailrotor.png",
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.menu_section_advanced)@",
            id = "advanced",
            module = "advanced",
            script = "menu.lua",
            image = "app/gfx/advanced.png",
            loaderspeed = "FAST",
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.menu_section_hardware)@",
            id = "hardware",
            module = "hardware",
            script = "menu.lua",
            image = "app/gfx/hardware.png",
            loaderspeed = "FAST",
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.menu_section_tools)@",
            id = "tools",
            module = "tools",
            script = "menu.lua",
            image = "app/gfx/tools.png",
            newline = true,
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.modules.logs.name)@",
            module = "logs",
            script = "logs_dir.lua",
            image = "app/modules/logs/gfx/logs.png",
            loaderspeed = "FAST",
            offline = true,
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.modules.settings.name)@",
            module = "settings",
            script = "settings.lua",
            image = "app/modules/settings/settings.png",
            offline = true,
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.modules.diagnostics.name)@",
            module = "diagnostics",
            script = "diagnostics.lua",
            image = "app/modules/diagnostics/diagnostics.png",
            bgtask = true,
            offline = true,
            ethosversion = {1, 6, 2}
        },
        {
            title = "@i18n(app.modules.settings.txt_developer)@",
            module = "developer",
            script = "developer.lua",
            image = "app/modules/developer/developer.png",
            developer = true,
            bgtask = true,
            offline = true,
            ethosversion = {1, 6, 2}
        }
    }
}
