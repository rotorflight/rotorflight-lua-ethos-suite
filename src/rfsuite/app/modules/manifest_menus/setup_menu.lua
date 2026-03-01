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
            image = "configuration/configuration.png",
            loaderspeed = 0.08,
            name = "@i18n(app.modules.configuration.name)@",
            order = 1,
            script = "configuration/configuration.lua",
            shortcutId = "s_setup_menu_configuration_configurati_fd32dd8698",
        },
        {
            image = "radio_config/radio_config.png",
            name = "@i18n(app.modules.radio_config.name)@",
            order = 2,
            script = "radio_config/radio_config.lua",
            shortcutId = "s_setup_menu_radio_config_radio_config_176a7167bd",
        },
        {
            image = "telemetry/telemetry.png",
            name = "@i18n(app.modules.telemetry.name)@",
            order = 3,
            script = "telemetry/telemetry.lua",
            shortcutId = "s_setup_menu_telemetry_telemetry_lua_72f812703b",
        },
        {
            image = "accelerometer/acc.png",
            loaderspeed = 0.08,
            name = "@i18n(app.modules.accelerometer.name)@",
            order = 4,
            script = "accelerometer/accelerometer.lua",
            shortcutId = "s_setup_menu_accelerometer_acceleromet_1e39c3bf97",
        },
        {
            image = "alignment/alignment.png",
            loaderspeed = 0.08,
            name = "@i18n(app.modules.alignment.name)@",
            order = 5,
            script = "alignment/alignment.lua",
            shortcutId = "s_setup_menu_alignment_alignment_lua_58dbca14ba",
        },
        {
            image = "ports/ports.png",
            name = "@i18n(app.modules.ports.name)@",
            order = 6,
            script = "ports/ports.lua",
            shortcutId = "s_setup_menu_ports_ports_lua_0511c48eaf",
        },
        {
            image = "mixer/mixer.png",
            loaderspeed = 0.08,
            menuId = "mixer",
            name = "@i18n(app.modules.mixer.name)@",
            order = 7,
            shortcutId = "s_setup_menu_mixer_f568f6ed70",
        },
        {
            image = "servos/servos.png",
            loaderspeed = 0.08,
            menuId = "servos_type",
            name = "@i18n(app.modules.servos.name)@",
            order = 8,
            shortcutId = "s_setup_menu_servos_type_065c3eb7e4",
        },
        {
            image = "failsafe/failsafe.png",
            menuId = "safety_menu",
            name = "@i18n(app.menu_section_controls)@",
            order = 9,
            shortcutId = "s_setup_menu_safety_menu_f14794af21",
        },
        {
            image = "power/power.png",
            menuId = "power",
            name = "@i18n(app.modules.power.name)@",
            order = 10,
            shortcutId = "s_setup_menu_power_73049b904c",
        },
        {
            image = "esc_motors/esc.png",
            menuId = "esc_motors",
            name = "@i18n(app.modules.esc_motors.name)@",
            order = 11,
            shortcutId = "s_setup_menu_esc_motors_5f43b662f9",
        },
        {
            image = "governor/governor.png",
            menuId = "governor",
            name = "@i18n(app.modules.governor.name)@",
            order = 11,
            shortcutId = "s_setup_menu_governor_753cc06e78",
        },
    },
    scriptPrefix = "app/modules/",
    title = "@i18n(app.modules.hardware_setup.name)@",
}
