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
    groups = {
        {
            title = "@i18n(app.menu_section_flight_tuning)@",
            menuId = "flight_tuning_menu",
            items = {
                { "s_flight_tuning_menu_pids_pids_lua_e97a40faab", "@i18n(app.modules.pids.name)@", false, "app/modules/pids/pids.lua", "app/modules/pids/pids.png", false },
                { "s_flight_tuning_menu_rates_rates_lua_853c5751ea", "@i18n(app.modules.rates.name)@", false, "app/modules/rates/rates.lua", "app/modules/rates/rates.png", false },
                {
                    "s_flight_tuning_menu_profile_governor_2361300e05",
                    "@i18n(app.modules.profile_governor.name)@",
                    false,
                    "app/modules/profile_governor/governor.lua",
                    "app/modules/profile_governor/governor.png",
                    {
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
                    },
                },
                { "s_flight_tuning_menu_advanced_menu_2abad2cdec", "@i18n(app.menu_section_advanced)@", "advanced_menu", false, "app/gfx/advanced.png", false },
            },
            menuContextId = "flight_tuning",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.hardware_setup.name)@",
            menuId = "setup_menu",
            items = {
                {
                    "s_setup_menu_configuration_configurati_fd32dd8698",
                    "@i18n(app.modules.configuration.name)@",
                    false,
                    "app/modules/configuration/configuration.lua",
                    "app/modules/configuration/configuration.png",
                    {
                        loaderspeed = 0.08,
                    },
                },
                { "s_setup_menu_radio_config_radio_config_176a7167bd", "@i18n(app.modules.radio_config.name)@", false, "app/modules/radio_config/radio_config.lua", "app/modules/radio_config/radio_config.png", false },
                { "s_setup_menu_telemetry_telemetry_lua_72f812703b", "@i18n(app.modules.telemetry.name)@", false, "app/modules/telemetry/telemetry.lua", "app/modules/telemetry/telemetry.png", false },
                {
                    "s_setup_menu_accelerometer_acceleromet_1e39c3bf97",
                    "@i18n(app.modules.accelerometer.name)@",
                    false,
                    "app/modules/accelerometer/accelerometer.lua",
                    "app/modules/accelerometer/acc.png",
                    {
                        loaderspeed = 0.08,
                    },
                },
                {
                    "s_setup_menu_alignment_alignment_lua_58dbca14ba",
                    "@i18n(app.modules.alignment.name)@",
                    false,
                    "app/modules/alignment/alignment.lua",
                    "app/modules/alignment/alignment.png",
                    {
                        loaderspeed = 0.08,
                    },
                },
                { "s_setup_menu_ports_ports_lua_0511c48eaf", "@i18n(app.modules.ports.name)@", false, "app/modules/ports/ports.lua", "app/modules/ports/ports.png", false },
                {
                    "s_setup_menu_mixer_f568f6ed70",
                    "@i18n(app.modules.mixer.name)@",
                    "mixer",
                    false,
                    "app/modules/mixer/mixer.png",
                    {
                        loaderspeed = 0.08,
                    },
                },
                {
                    "s_setup_menu_servos_type_065c3eb7e4",
                    "@i18n(app.modules.servos.name)@",
                    "servos_type",
                    false,
                    "app/modules/servos/servos.png",
                    {
                        loaderspeed = 0.08,
                    },
                },
                { "s_setup_menu_safety_menu_f14794af21", "@i18n(app.menu_section_controls)@", "safety_menu", false, "app/modules/failsafe/failsafe.png", false },
                { "s_setup_menu_power_73049b904c", "@i18n(app.modules.power.name)@", "power", false, "app/modules/power/power.png", false },
                { "s_setup_menu_esc_motors_5f43b662f9", "@i18n(app.modules.esc_motors.name)@", "esc_motors", false, "app/modules/esc_motors/esc.png", false },
                { "s_setup_menu_governor_753cc06e78", "@i18n(app.modules.governor.name)@", "governor", false, "app/modules/governor/governor.png", false },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.menu_section_tools)@",
            menuId = "tools_menu",
            items = {
                {
                    "s_tools_menu_copyprofiles_copyprofiles_020f84c51f",
                    "@i18n(app.modules.copyprofiles.name)@",
                    false,
                    "app/modules/copyprofiles/copyprofiles.lua",
                    "app/modules/copyprofiles/copy.png",
                    {
                        offline = false,
                        bgtask = true,
                        disabled = true,
                        apiversion = { 12, 0, 6 },
                    },
                },
                {
                    "s_tools_menu_profile_select_select_pro_b62834ef6e",
                    "@i18n(app.modules.profile_select.name)@",
                    false,
                    "app/modules/profile_select/select_profile.lua",
                    "app/modules/profile_select/select_profile.png",
                    {
                        offline = false,
                        bgtask = true,
                        apiversion = { 12, 0, 6 },
                    },
                },
                {
                    "s_tools_menu_diagnostics_7095acfa6e",
                    "@i18n(app.modules.diagnostics.name)@",
                    "diagnostics",
                    false,
                    "app/modules/diagnostics/diagnostics.png",
                    {
                        offline = true,
                    },
                },
            },
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.settings.name)@",
            menuId = "settings_admin",
            items = {
                {
                    "s_settings_admin_tools_general_lua_37954a091f",
                    "@i18n(app.modules.settings.txt_general)@",
                    false,
                    "settings/tools/general.lua",
                    "app/modules/settings/gfx/general.png",
                    {
                        offline = true,
                    },
                },
                {
                    "s_settings_admin_tools_shortcuts_lua_7ef1a52bf9",
                    "@i18n(app.modules.settings.shortcuts)@",
                    false,
                    "settings/tools/shortcuts.lua",
                    "app/modules/settings/gfx/shortcuts.png",
                    {
                        offline = true,
                    },
                },
                {
                    "s_settings_admin_tools_features_lua_0befe584ca",
                    "@i18n(app.modules.settings.features)@",
                    false,
                    "settings/tools/features.lua",
                    "app/modules/settings/gfx/features.png",
                    {
                        offline = true,
                    },
                },
                {
                    "s_settings_admin_tools_dashboard_lua_949703e179",
                    "@i18n(app.modules.settings.dashboard)@",
                    false,
                    "settings/tools/dashboard.lua",
                    "app/modules/settings/gfx/dashboard.png",
                    {
                        offline = true,
                        bgtask = true,
                    },
                },
                {
                    "s_settings_admin_activelook_lua_cac11316fe",
                    "ActiveLook",
                    false,
                    "settings/activelook.lua",
                    "app/modules/settings/gfx/activelook.png",
                    {
                        offline = true,
                        ethosversion = { 1, 7, 0 },
                    },
                },
                {
                    "s_settings_admin_tools_localizations_l_bfcda87566",
                    "@i18n(app.modules.settings.localizations)@",
                    false,
                    "settings/tools/localizations.lua",
                    "app/modules/settings/gfx/localizations.png",
                    {
                        offline = true,
                    },
                },
                {
                    "s_settings_admin_tools_audio_lua_54f65112f1",
                    "@i18n(app.modules.settings.audio)@",
                    false,
                    "settings/tools/audio.lua",
                    "app/modules/settings/gfx/audio.png",
                    {
                        offline = true,
                    },
                },
            },
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.menu_section_advanced)@",
            menuId = "advanced_menu",
            items = {
                { "s_advanced_menu_filters_filters_lua_f1de87c4bd", "@i18n(app.modules.filters.name)@", false, "app/modules/filters/filters.lua", "app/modules/filters/filters.png", false },
                {
                    "s_advanced_menu_profile_pidcontroller_d88ea3ba97",
                    "@i18n(app.modules.profile_pidcontroller.name)@",
                    false,
                    "app/modules/profile_pidcontroller/pidcontroller.lua",
                    "app/modules/profile_pidcontroller/pids-controller.png",
                    {
                        apiversion = { 12, 0, 6 },
                    },
                },
                {
                    "s_advanced_menu_profile_pidbandwidth_p_650df8805e",
                    "@i18n(app.modules.profile_pidbandwidth.name)@",
                    false,
                    "app/modules/profile_pidbandwidth/pidbandwidth.lua",
                    "app/modules/profile_pidbandwidth/pids-bandwidth.png",
                    {
                        apiversion = { 12, 0, 6 },
                    },
                },
                {
                    "s_advanced_menu_profile_autolevel_auto_d9832fb3eb",
                    "@i18n(app.modules.profile_autolevel.name)@",
                    false,
                    "app/modules/profile_autolevel/autolevel.lua",
                    "app/modules/profile_autolevel/autolevel.png",
                    {
                        apiversion = { 12, 0, 6 },
                    },
                },
                {
                    "s_advanced_menu_profile_mainrotor_main_99724a655d",
                    "@i18n(app.modules.profile_mainrotor.name)@",
                    false,
                    "app/modules/profile_mainrotor/mainrotor.lua",
                    "app/modules/profile_mainrotor/mainrotor.png",
                    {
                        apiversion = { 12, 0, 6 },
                    },
                },
                {
                    "s_advanced_menu_profile_tailrotor_tail_9cd82ec0d9",
                    "@i18n(app.modules.profile_tailrotor.name)@",
                    false,
                    "app/modules/profile_tailrotor/tailrotor.lua",
                    "app/modules/profile_tailrotor/tailrotor.png",
                    {
                        apiversion = { 12, 0, 6 },
                    },
                },
                {
                    "s_advanced_menu_profile_rescue_rescue_3bb5c29dca",
                    "@i18n(app.modules.profile_rescue.name)@",
                    false,
                    "app/modules/profile_rescue/rescue.lua",
                    "app/modules/profile_rescue/rescue.png",
                    {
                        apiversion = { 12, 0, 6 },
                    },
                },
                {
                    "s_advanced_menu_rates_advanced_rates_a_ef4795e385",
                    "@i18n(app.modules.rates_advanced.name)@",
                    false,
                    "app/modules/rates_advanced/rates_advanced.lua",
                    "app/modules/rates_advanced/rates.png",
                    {
                        apiversion = { 12, 0, 6 },
                    },
                },
            },
            menuContextId = "flight_tuning",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.mixer.name)@",
            menuId = "mixer",
            items = {
                {
                    "s_mixer_swash_lua_219836e7bb",
                    "@i18n(app.modules.mixer.swash)@",
                    false,
                    "mixer/tools/swash.lua",
                    "app/modules/mixer/gfx/swash.png",
                    {
                        apiversion = { 12, 0, 9 },
                    },
                },
                {
                    "s_mixer_swash_legacy_lua_c1fdc218f2",
                    "@i18n(app.modules.mixer.swash)@",
                    false,
                    "mixer/tools/swash_legacy.lua",
                    "app/modules/mixer/gfx/swash.png",
                    {
                        apiversionlt = { 12, 0, 9 },
                    },
                },
                {
                    "s_mixer_swashgeometry_lua_2b19036cb9",
                    "@i18n(app.modules.mixer.geometry)@",
                    false,
                    "mixer/tools/swashgeometry.lua",
                    "app/modules/mixer/gfx/geometry.png",
                    {
                        apiversion = { 12, 0, 9 },
                    },
                },
                {
                    "s_mixer_tail_lua_4dae4bbc4e",
                    "@i18n(app.modules.mixer.tail)@",
                    false,
                    "mixer/tools/tail.lua",
                    "app/modules/mixer/gfx/tail.png",
                    {
                        apiversion = { 12, 0, 9 },
                    },
                },
                {
                    "s_mixer_tail_legacy_lua_af252b8ccf",
                    "@i18n(app.modules.mixer.tail)@",
                    false,
                    "mixer/tools/tail_legacy.lua",
                    "app/modules/mixer/gfx/tail.png",
                    {
                        apiversionlt = { 12, 0, 9 },
                    },
                },
                { "s_mixer_trims_lua_89bbcb71cc", "@i18n(app.modules.mixer.trims)@", false, "mixer/tools/trims.lua", "app/modules/mixer/gfx/trims.png", false },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.servos.name)@",
            menuId = "servos_type",
            items = {
                { "s_servos_type_pwm_lua_401567fa69", "@i18n(app.modules.servos.pwm)@", false, "servos/tools/pwm.lua", "app/modules/servos/gfx/pwm.png", false },
                { "s_servos_type_bus_lua_a5236c586f", "@i18n(app.modules.servos.bus)@", false, "servos/tools/bus.lua", "app/modules/servos/gfx/bus.png", false },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.menu_section_controls)@",
            menuId = "safety_menu",
            items = {
                {
                    "s_safety_menu_modes_modes_lua_4bfa50db9c",
                    "@i18n(app.modules.modes.name)@",
                    false,
                    "app/modules/modes/modes.lua",
                    "app/modules/modes/modes.png",
                    {
                        loaderspeed = 0.05,
                    },
                },
                {
                    "s_safety_menu_adjustments_adjustments_1aa898354c",
                    "@i18n(app.modules.adjustments.name)@",
                    false,
                    "app/modules/adjustments/adjustments.lua",
                    "app/modules/adjustments/adjustments.png",
                    {
                        loaderspeed = 0.1,
                    },
                },
                { "s_safety_menu_failsafe_failsafe_lua_5033612baf", "@i18n(app.modules.failsafe.name)@", false, "app/modules/failsafe/failsafe.lua", "app/modules/failsafe/failsafe.png", false },
                { "s_safety_menu_beepers_7440548a09", "@i18n(app.modules.beepers.name)@", "beepers", false, "app/modules/beepers/beepers.png", false },
                { "s_safety_menu_blackbox_91e70d8f9f", "@i18n(app.modules.blackbox.name)@", "blackbox", false, "app/modules/blackbox/blackbox.png", false },
                { "s_safety_menu_stats_stats_lua_6e4a1dfd3e", "@i18n(app.modules.stats.name)@", false, "app/modules/stats/stats.lua", "app/modules/stats/stats.png", false },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.power.name)@",
            menuId = "power",
            items = {
                {
                    "s_power_battery_lua_f67116c271",
                    "@i18n(app.modules.power.battery_name)@",
                    false,
                    "power/tools/battery.lua",
                    "app/modules/power/gfx/battery.png",
                    {
                        apiversion = { 12, 0, 9 },
                    },
                },
                {
                    "s_power_battery_legacy_lua_71177b8cf6",
                    "@i18n(app.modules.power.battery_name)@",
                    false,
                    "power/tools/battery_legacy.lua",
                    "app/modules/power/gfx/battery.png",
                    {
                        apiversionlt = { 12, 0, 9 },
                    },
                },
                { "s_power_alerts_lua_9fd7dbdc4d", "@i18n(app.modules.power.alert_name)@", false, "power/tools/alerts.lua", "app/modules/power/gfx/alerts.png", false },
                { "s_power_source_lua_6d24f8cd57", "@i18n(app.modules.power.source_name)@", false, "power/tools/source.lua", "app/modules/power/gfx/source.png", false },
                { "s_power_smartfuel_lua_e08268e43e", "@i18n(app.modules.power.smartfuel_name)@", false, "power/tools/smartfuel.lua", "app/modules/power/gfx/smartfuel.png", false },
                { "s_power_preferences_lua_2bae48fe41", "@i18n(app.modules.power.preferences_name)@", false, "power/tools/preferences.lua", "app/modules/power/gfx/preferences.png", false },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.esc_motors.name)@",
            menuId = "esc_motors",
            items = {
                { "s_esc_motors_throttle_lua_17f21fa300", "@i18n(app.modules.esc_motors.throttle)@", false, "esc_motors/tools/throttle.lua", "app/modules/esc_motors/gfx/throttle.png", false },
                { "s_esc_motors_telemetry_lua_a9d9e2a50a", "@i18n(app.modules.esc_motors.telemetry)@", false, "esc_motors/tools/telemetry.lua", "app/modules/esc_motors/gfx/telemetry.png", false },
                { "s_esc_motors_rpm_lua_19b6337da0", "@i18n(app.modules.esc_motors.rpm)@", false, "esc_motors/tools/rpm.lua", "app/modules/esc_motors/gfx/rpm.png", false },
                {
                    "s_powertrain_menu_esc_tools_tools_esc_0ded099fe9",
                    "@i18n(app.modules.esc_tools.name)@",
                    false,
                    "app/modules/esc_tools/tools/esc.lua",
                    "app/modules/esc_tools/esc.png",
                    {
                        loaderspeed = false,
                        offline = false,
                    },
                },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.governor.name)@",
            menuId = "governor",
            items = {
                { "s_governor_general_lua_bb876f329d", "@i18n(app.modules.governor.menu_general)@", false, "governor/tools/general.lua", "app/modules/governor/gfx/general.png", false },
                { "s_governor_time_lua_3fa58c3610", "@i18n(app.modules.governor.menu_time)@", false, "governor/tools/time.lua", "app/modules/governor/gfx/time.png", false },
                { "s_governor_filters_lua_258e16a592", "@i18n(app.modules.governor.menu_filters)@", false, "governor/tools/filters.lua", "app/modules/governor/gfx/filters.png", false },
                { "s_governor_curves_lua_a8f9b2b504", "@i18n(app.modules.governor.menu_curves)@", false, "governor/tools/curves.lua", "app/modules/governor/gfx/curves.png", false },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.diagnostics.name)@",
            menuId = "diagnostics",
            items = {
                {
                    "s_diagnostics_rfstatus_lua_ac6fe96c58",
                    "@i18n(app.modules.rfstatus.name)@",
                    false,
                    "diagnostics/tools/rfstatus.lua",
                    "app/modules/diagnostics/gfx/rfstatus.png",
                    {
                        offline = true,
                        bgtask = false,
                    },
                },
                {
                    "s_diagnostics_elrs_telemetry_lua_5af0394dfc",
                    "@i18n(app.modules.elrs_telemetry.name)@",
                    false,
                    "diagnostics/tools/elrs_telemetry.lua",
                    "app/modules/diagnostics/gfx/elrs_link.png",
                    {
                        offline = false,
                        bgtask = true,
                    },
                },
                {
                    "s_diagnostics_sensors_lua_0010694864",
                    "@i18n(app.modules.validate_sensors.name)@",
                    false,
                    "diagnostics/tools/sensors.lua",
                    "app/modules/diagnostics/gfx/sensors.png",
                    {
                        offline = true,
                        bgtask = true,
                    },
                },
                {
                    "s_diagnostics_smartfuel_lua_b5746f8b8c",
                    "@i18n(app.modules.power.smartfuel_name)@",
                    false,
                    "diagnostics/tools/smartfuel.lua",
                    "app/modules/diagnostics/gfx/smartfuel.png",
                    {
                        offline = false,
                        bgtask = true,
                    },
                },
                {
                    "s_diagnostics_fblsensors_lua_05321e9f3c",
                    "@i18n(app.modules.fblsensors.name)@",
                    false,
                    "diagnostics/tools/fblsensors.lua",
                    "app/modules/diagnostics/gfx/fblsensors.png",
                    {
                        offline = false,
                        bgtask = true,
                    },
                },
                {
                    "s_diagnostics_fblstatus_lua_d9afde0a7c",
                    "@i18n(app.modules.fblstatus.name)@",
                    false,
                    "diagnostics/tools/fblstatus.lua",
                    "app/modules/diagnostics/gfx/fblstatus.png",
                    {
                        offline = false,
                        bgtask = true,
                    },
                },
                {
                    "s_diagnostics_info_lua_5025a3d5b5",
                    "@i18n(app.modules.info.name)@",
                    false,
                    "diagnostics/tools/info.lua",
                    "app/modules/diagnostics/gfx/info.png",
                    {
                        offline = true,
                        bgtask = true,
                    },
                },
                {
                    "s_diagnostics_session_logs_lua_77ba90cd72",
                    "Session Logs",
                    false,
                    "diagnostics/tools/session_logs.lua",
                    "app/modules/diagnostics/gfx/session_logs.png",
                    {
                        offline = true,
                        bgtask = true,
                    },
                },
            },
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.beepers.name)@",
            menuId = "beepers",
            items = {
                { "s_beepers_configuration_lua_3d60a90251", "@i18n(app.modules.beepers.menu_configuration)@", false, "beepers/tools/configuration.lua", "app/modules/beepers/gfx/configuration.png", false },
                { "s_beepers_dshot_lua_f1e47cbff2", "@i18n(app.modules.beepers.menu_dshot)@", false, "beepers/tools/dshot.lua", "app/modules/beepers/gfx/dshot.png", false },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
        {
            title = "@i18n(app.modules.blackbox.name)@",
            menuId = "blackbox",
            items = {
                { "s_blackbox_configuration_lua_1b07855e2c", "@i18n(app.modules.blackbox.menu_configuration)@", false, "blackbox/tools/configuration.lua", "app/modules/blackbox/gfx/configuration.png", false },
                { "s_blackbox_logging_lua_6216852e49", "@i18n(app.modules.blackbox.menu_logging)@", false, "blackbox/tools/logging.lua", "app/modules/blackbox/gfx/logging.png", false },
                { "s_blackbox_status_lua_6d398bae79", "@i18n(app.modules.blackbox.menu_status)@", false, "blackbox/tools/status.lua", "app/modules/blackbox/gfx/status.png", false },
            },
            menuContextId = "setup",
            visibility = {
                {
                    ethosversion = { 1, 6, 2 },
                },
            },
        },
    },
}
