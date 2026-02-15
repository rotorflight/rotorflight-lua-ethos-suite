--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- Explicit menu structure.
-- Each entry can define:
--   - title: UI label (i18n string recommended).
--   - entry: module folder to open directly from the main menu.
--   - pages: list of module folders (or override tables) to build a submenu.
--   - id: section identifier used by openMainMenuSub (required for submenu sections).
--   - image: icon path used on the main menu.
--   - loaderspeed: loader speed multiplier (float) or alias ("FAST", "DEFAULT", "SLOW").
--   - script_by_mspversion: list of {op, version, script} overrides for MSP API.
--   - script_default: fallback script if no version rule matches.
--   - offline: allow entry when FC is not connected.
--   - bgtask: allow entry while background task is active.
--   - newline: start a new header group (UI layout).
return {
    sections = {
        {
            title = "@i18n(app.modules.pids.name)@",
            entry = "pids",
            image = "app/modules/pids/pids.png"
        },
        {
            title = "@i18n(app.modules.rates.name)@",
            entry = "rates",
            image = "app/modules/rates/rates.png"
        },
        {
            title = "@i18n(app.modules.profile_governor.name)@",
            entry = "profile_governor",
            image = "app/modules/profile_governor/governor.png",
            script_by_mspversion = {
                {">=", "12.09", "governor.lua", loaderspeed = "FAST"},
                {"<", "12.09", "governor_legacy.lua", loaderspeed = "SLOW"}
            }
        },
        {
            title = "@i18n(app.modules.profile_tailrotor.name)@",
            entry = "tailrotor",
            image = "app/modules/tailrotor/tailrotor.png"
        },
        -- A section with pages opens a submenu.
        {
            title = "@i18n(app.menu_section_advanced)@",
            id = "advanced",
            image = "app/gfx/advanced.png",
            loaderspeed = "FAST",
            pages = {
                "profile_pidcontroller",
                "profile_pidbandwidth",
                "profile_autolevel",
                "profile_mainrotor",
                "profile_tailrotor",
                "profile_rescue",
                "rates_advanced"
            }
        },
        {
            title = "@i18n(app.menu_section_hardware)@",
            id = "hardware",
            image = "app/gfx/hardware.png",
            loaderspeed = "FAST",
            pages = {
                "servos",
                "mixer",
                "esc_motors",
                "accelerometer",
                "telemetry",
                "filters",
                "power",
                "radio_config",
                "stats",
                "failsafe",
                "adjustments",
                {"governor", script_by_mspversion = {
                    {">=", "12.09", "governor.lua", loaderspeed = "FAST"},
                    {"<", "12.09", "governor_legacy.lua", loaderspeed = "SLOW"}
                }},
                "modes"
            }
        },
        {
            title = "@i18n(app.menu_section_tools)@",
            id = "tools",
            image = "app/gfx/tools.png",
            newline = true,
            pages = {
                "copyprofiles",
                "profile_select",
                "msp_exp"
            }
        },
        -- Single entries open directly from the main menu.
        {
            title = "@i18n(app.modules.logs.name)@",
            entry = "logs",
            image = "app/modules/logs/gfx/logs.png",
            loaderspeed = "FAST",
            offline = true
        },
        {
            title = "@i18n(app.modules.settings.name)@",
            entry = "settings",
            image = "app/modules/settings/settings.png",
            offline = true
        },
        {
            title = "@i18n(app.modules.diagnostics.name)@",
            entry = "diagnostics",
            image = "app/modules/diagnostics/diagnostics.png",
            bgtask = true,
            offline = true
        }
    }
}
