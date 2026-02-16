--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

-- Module-backed menu manifest.
-- `sections` define main-menu groups; each group provides `sections = { ... }` entries.
-- `menus` define submenu pages used by submenu_builder.createFromManifest().
-- `menuId` targets are loaded through `app/modules/manifest_menu/menu.lua`.
-- That router keeps this file as the single source of menu structure and avoids
-- creating one wrapper `menu.lua` per submenu.
-- API gates use table versions. For padded-minor releases prefer `{major, 0, minor}`
-- so `12.09` remains explicit before moving to `12.10`.

return {
    sections = {
        {
            id = "configuration",
            title = "@i18n(app.header_configuration)@",
            sections = {
                {
                    title = "@i18n(app.menu_section_flight_tuning)@",
                    id = "flight_tuning",
                    menuId = "flight_tuning_menu",
                    image = "app/gfx/flight_tuning.png",
                    loaderspeed = "FAST",
                    ethosversion = {1, 6, 2}
                },
                {
                    title = "@i18n(app.modules.hardware_setup.name)@",
                    id = "setup",
                    menuId = "setup_menu",
                    image = "app/gfx/hardware.png",
                    loaderspeed = "FAST",
                    ethosversion = {1, 6, 2}
                },
                {
                    title = "@i18n(app.menu_section_mechanics)@",
                    id = "mechanics",
                    menuId = "mechanics_menu",
                    image = "app/modules/mixer/mixer.png",
                    loaderspeed = "FAST",
                    ethosversion = {1, 6, 2}
                },
                {
                    title = "@i18n(app.menu_section_controls)@",
                    id = "safety",
                    menuId = "safety_menu",
                    image = "app/modules/failsafe/failsafe.png",
                    loaderspeed = "FAST",
                    ethosversion = {1, 6, 2}
                }
            }
        },
        {
            id = "system",
            title = "@i18n(app.header_system)@",
            sections = {
                {
                    title = "@i18n(app.menu_section_tools)@",
                    menuId = "tools_menu",
                    image = "app/gfx/tools.png",
                    offline = true,
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
                    menuId = "settings_admin",
                    image = "app/modules/settings/settings.png",
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
    },
    menus = {
        setup_menu = {
            title = "@i18n(app.modules.hardware_setup.name)@",
            scriptPrefix = "app/modules/",
            iconPrefix = "app/modules/",
            loaderSpeed = "FAST",
            navOptions = {showProgress = true},
            pages = {
                {name = "@i18n(app.modules.configuration.name)@", script = "configuration/configuration.lua", image = "configuration/configuration.png", order = 1, loaderspeed = 0.08},
                {name = "@i18n(app.modules.radio_config.name)@", script = "radio_config/radio_config.lua", image = "radio_config/radio_config.png", order = 2},
                {name = "@i18n(app.modules.telemetry.name)@", script = "telemetry/telemetry.lua", image = "telemetry/telemetry.png", order = 3},
                {name = "@i18n(app.modules.accelerometer.name)@", script = "accelerometer/accelerometer.lua", image = "accelerometer/acc.png", order = 4, loaderspeed = 0.08},
                {name = "@i18n(app.modules.alignment.name)@", script = "alignment/alignment.lua", image = "alignment/alignment.png", order = 5, loaderspeed = 0.08},
                {name = "@i18n(app.modules.ports.name)@", script = "ports/ports.lua", image = "ports/ports.png", order = 6}
            }
        },
        flight_tuning_menu = {
            title = "@i18n(app.menu_section_flight_tuning)@",
            scriptPrefix = "app/modules/",
            iconPrefix = "app/modules/",
            loaderSpeed = "FAST",
            navOptions = {showProgress = true},
            pages = {
                {name = "@i18n(app.modules.pids.name)@", script = "pids/pids.lua", image = "pids/pids.png", order = 1},
                {name = "@i18n(app.modules.rates.name)@", script = "rates/rates.lua", image = "rates/rates.png", order = 2},
                {name = "@i18n(app.modules.profile_governor.name)@", menuId = "profile_governor", image = "profile_governor/governor.png", order = 3, apiversion = {12, 0, 9}},
                {name = "@i18n(app.modules.profile_governor.name)@", script = "profile_governor/governor_legacy.lua", image = "profile_governor/governor.png", order = 3, apiversionlt = {12, 0, 9}},
                {name = "@i18n(app.menu_section_advanced)@", menuId = "advanced_menu", image = "app/gfx/advanced.png", order = 4}
            }
        },
        profiles_menu = {
            title = "@i18n(app.menu_section_profiles)@",
            scriptPrefix = "app/modules/",
            iconPrefix = "app/modules/",
            loaderSpeed = "FAST",
            navOptions = {defaultSection = "flight_tuning", showProgress = true},
            pages = {
                {name = "@i18n(app.modules.profile_select.name)@", script = "profile_select/select_profile.lua", image = "profile_select/select_profile.png", order = 1, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_mainrotor.name)@", script = "profile_mainrotor/mainrotor.lua", image = "profile_mainrotor/mainrotor.png", order = 2, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_tailrotor.name)@", script = "profile_tailrotor/tailrotor.lua", image = "profile_tailrotor/tailrotor.png", order = 3, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_rescue.name)@", script = "profile_rescue/rescue.lua", image = "profile_rescue/rescue.png", order = 4, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_autolevel.name)@", script = "profile_autolevel/autolevel.lua", image = "profile_autolevel/autolevel.png", order = 5, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_pidcontroller.name)@", script = "profile_pidcontroller/pidcontroller.lua", image = "profile_pidcontroller/pids-controller.png", order = 6, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_pidbandwidth.name)@", script = "profile_pidbandwidth/pidbandwidth.lua", image = "profile_pidbandwidth/pids-bandwidth.png", order = 7, apiversion = {12, 0, 6}}
            }
        },
        mechanics_menu = {
            title = "@i18n(app.menu_section_mechanics)@",
            scriptPrefix = "app/modules/",
            iconPrefix = "app/modules/",
            loaderSpeed = "FAST",
            navOptions = {showProgress = true},
            pages = {
                {name = "@i18n(app.modules.esc_motors.name)@", menuId = "esc_motors", image = "esc_motors/esc.png", order = 1, loaderspeed = 0.08},
                {name = "@i18n(app.modules.mixer.name)@", menuId = "mixer", image = "mixer/mixer.png", order = 2, loaderspeed = 0.08},
                {name = "@i18n(app.modules.servos.name)@", menuId = "servos_type", image = "servos/servos.png", order = 3, loaderspeed = 0.08},
                {name = "@i18n(app.modules.power.name)@", menuId = "power", image = "power/power.png", order = 4},
                {name = "@i18n(app.modules.governor.name)@", menuId = "governor", image = "governor/governor.png", order = 5, apiversion = {12, 0, 9}},
                {name = "@i18n(app.modules.governor.name)@", script = "governor/governor_legacy.lua", image = "governor/governor.png", order = 5, apiversionlt = {12, 0, 9}}
            }
        },
        safety_menu = {
            title = "@i18n(app.menu_section_controls)@",
            scriptPrefix = "app/modules/",
            iconPrefix = "app/modules/",
            loaderSpeed = "FAST",
            navOptions = {showProgress = true},
            pages = {
                {name = "@i18n(app.modules.modes.name)@", script = "modes/modes.lua", image = "modes/modes.png", order = 1, loaderspeed = 0.05},
                {name = "@i18n(app.modules.adjustments.name)@", script = "adjustments/adjustments.lua", image = "adjustments/adjustments.png", order = 2, loaderspeed = 0.1},
                {name = "@i18n(app.modules.failsafe.name)@", script = "failsafe/failsafe.lua", image = "failsafe/failsafe.png", order = 3},
                {name = "@i18n(app.modules.beepers.name)@", menuId = "beepers", image = "beepers/beepers.png", order = 4},
                {name = "@i18n(app.modules.blackbox.name)@", menuId = "blackbox", image = "blackbox/blackbox.png", order = 5},
                {name = "@i18n(app.modules.stats.name)@", script = "stats/stats.lua", image = "stats/stats.png", order = 6}
            }
        },
        tools_menu = {
            title = "@i18n(app.menu_section_tools)@",
            scriptPrefix = "app/modules/",
            iconPrefix = "app/modules/",
            navOptions = {defaultSection = "system", showProgress = true},
            pages = {
                {name = "@i18n(app.modules.copyprofiles.name)@", script = "copyprofiles/copyprofiles.lua", image = "copyprofiles/copy.png", order = 1, apiversion = {12, 0, 6}, disabled = true, offline = false},
                {name = "@i18n(app.modules.profile_select.name)@", script = "profile_select/select_profile.lua", image = "profile_select/select_profile.png", order = 2, apiversion = {12, 0, 6}, offline = false},
                {name = "@i18n(app.modules.esc_tools.name)@", script = "esc_tools/tools/esc.lua", image = "esc_tools/esc.png", order = 3, offline = false},
                {name = "@i18n(app.modules.diagnostics.name)@", menuId = "diagnostics", image = "diagnostics/diagnostics.png", order = 4, offline = true}
            }
        },
        advanced_menu = {
            title = "@i18n(app.menu_section_advanced)@",
            scriptPrefix = "app/modules/",
            iconPrefix = "app/modules/",
            loaderSpeed = "FAST",
            navOptions = {showProgress = true},
            pages = {
                {name = "@i18n(app.modules.filters.name)@", script = "filters/filters.lua", image = "filters/filters.png", order = 1},
                {name = "@i18n(app.modules.profile_pidcontroller.name)@", script = "profile_pidcontroller/pidcontroller.lua", image = "profile_pidcontroller/pids-controller.png", order = 2, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_pidbandwidth.name)@", script = "profile_pidbandwidth/pidbandwidth.lua", image = "profile_pidbandwidth/pids-bandwidth.png", order = 3, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_autolevel.name)@", script = "profile_autolevel/autolevel.lua", image = "profile_autolevel/autolevel.png", order = 4, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_mainrotor.name)@", script = "profile_mainrotor/mainrotor.lua", image = "profile_mainrotor/mainrotor.png", order = 5, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_tailrotor.name)@", script = "profile_tailrotor/tailrotor.lua", image = "profile_tailrotor/tailrotor.png", order = 6, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.profile_rescue.name)@", script = "profile_rescue/rescue.lua", image = "profile_rescue/rescue.png", order = 7, apiversion = {12, 0, 6}},
                {name = "@i18n(app.modules.rates_advanced.name)@", script = "rates_advanced/rates_advanced.lua", image = "rates_advanced/rates.png", order = 8, apiversion = {12, 0, 6}}
            }
        },
        hardware_menu = {
            title = "@i18n(app.menu_section_hardware)@",
            scriptPrefix = "app/modules/",
            loaderSpeed = "FAST",
            navOptions = {showProgress = true},
            pages = {
                {name = "@i18n(app.modules.configuration.name)@", script = "configuration/configuration.lua", image = "app/modules/configuration/configuration.png", order = 1, loaderspeed = 0.08},
                {name = "@i18n(app.modules.servos.name)@", script = "servos/servos.lua", image = "app/modules/servos/servos.png", order = 2, loaderspeed = 0.08},
                {name = "@i18n(app.modules.mixer.name)@", script = "mixer/mixer.lua", image = "app/modules/mixer/mixer.png", order = 3, loaderspeed = 0.08},
                {name = "@i18n(app.modules.esc_motors.name)@", script = "esc_motors/esc_motors.lua", image = "app/modules/esc_motors/esc.png", order = 4, loaderspeed = 0.08},
                {name = "@i18n(app.modules.accelerometer.name)@", script = "accelerometer/accelerometer.lua", image = "app/modules/accelerometer/acc.png", order = 5, loaderspeed = 0.08},
                {name = "@i18n(app.modules.alignment.name)@", script = "alignment/alignment.lua", image = "app/modules/alignment/alignment.png", order = 6, loaderspeed = 0.08},
                {name = "@i18n(app.modules.ports.name)@", script = "ports/ports.lua", image = "app/modules/ports/ports.png", order = 7, loaderspeed = 0.08},
                {name = "@i18n(app.modules.telemetry.name)@", script = "telemetry/telemetry.lua", image = "app/modules/telemetry/telemetry.png", order = 8},
                {name = "@i18n(app.modules.radio_config.name)@", script = "radio_config/radio_config.lua", image = "app/modules/radio_config/radio_config.png", order = 9},
                {name = "@i18n(app.modules.beepers.name)@", script = "beepers/beepers.lua", image = "app/modules/beepers/beepers.png", order = 10},
                {name = "@i18n(app.modules.blackbox.name)@", script = "blackbox/blackbox.lua", image = "app/modules/blackbox/blackbox.png", order = 11},
                {name = "@i18n(app.modules.stats.name)@", script = "stats/stats.lua", image = "app/modules/stats/stats.png", order = 12},
                {name = "@i18n(app.modules.failsafe.name)@", script = "failsafe/failsafe.lua", image = "app/modules/failsafe/failsafe.png", order = 13},
                {name = "@i18n(app.modules.modes.name)@", script = "modes/modes.lua", image = "app/modules/modes/modes.png", order = 14, loaderspeed = 0.05},
                {name = "@i18n(app.modules.adjustments.name)@", script = "adjustments/adjustments.lua", image = "app/modules/adjustments/adjustments.png", order = 15, loaderspeed = 0.1},
                {name = "@i18n(app.modules.filters.name)@", script = "filters/filters.lua", image = "app/modules/filters/filters.png", order = 16},
                {name = "@i18n(app.modules.power.name)@", script = "power/power.lua", image = "app/modules/power/power.png", order = 17},
                {name = "@i18n(app.modules.governor.name)@", script = "governor/governor.lua", image = "app/modules/governor/governor.png", order = 18, apiversion = {12, 0, 9}},
                {name = "@i18n(app.modules.governor.name)@", script = "governor/governor_legacy.lua", image = "app/modules/governor/governor.png", order = 18, apiversionlt = {12, 0, 9}}
            }
        },
        power = {
            title = "@i18n(app.modules.power.name)@",
            scriptPrefix = "power/tools/",
            iconPrefix = "app/modules/power/gfx/",
            loaderSpeed = 0.08,
            navOptions = {defaultSection = "mechanics"},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            pages = {
                {name = "@i18n(app.modules.power.battery_name)@", script = "battery.lua", image = "battery.png"},
                {name = "@i18n(app.modules.power.alert_name)@", script = "alerts.lua", image = "alerts.png"},
                {name = "@i18n(app.modules.power.source_name)@", script = "source.lua", image = "source.png"}
            }
        },
        esc_motors = {
            title = "@i18n(app.modules.esc_motors.name)@",
            scriptPrefix = "esc_motors/tools/",
            iconPrefix = "app/modules/esc_motors/gfx/",
            loaderSpeed = 0.08,
            navOptions = {defaultSection = "mechanics", showProgress = true},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            hooksScript = "app/modules/esc_motors/menu_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.esc_motors.throttle)@", script = "throttle.lua", image = "throttle.png"},
                {name = "@i18n(app.modules.esc_motors.telemetry)@", script = "telemetry.lua", image = "telemetry.png"},
                {name = "@i18n(app.modules.esc_motors.rpm)@", script = "rpm.lua", image = "rpm.png"}
            }
        },
        developer = {
            title = "@i18n(app.modules.settings.txt_developer)@",
            loaderSpeed = 0.08,
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            childTitleResolver = function(_, item)
                return "@i18n(app.modules.settings.txt_developer)@ / " .. item.name
            end,
            pages = {
                {name = "@i18n(app.modules.msp_speed.name)@", script = "developer/tools/msp_speed.lua", image = "app/modules/developer/gfx/msp_speed.png", bgtask = true, offline = false},
                {name = "@i18n(app.modules.api_tester.name)@", script = "developer/tools/api_tester.lua", image = "app/modules/developer/gfx/api_tester.png", bgtask = true, offline = false},
                {name = "@i18n(app.modules.msp_exp.name)@", script = "developer/tools/msp_exp.lua", image = "app/modules/developer/gfx/msp_exp.png", bgtask = true, offline = false},
                {name = "@i18n(app.modules.settings.name)@", script = "settings/tools/development.lua", image = "app/modules/developer/gfx/settings.png", bgtask = true, offline = true}
            }
        },
        diagnostics = {
            title = "@i18n(app.modules.diagnostics.name)@",
            scriptPrefix = "diagnostics/tools/",
            iconPrefix = "app/modules/diagnostics/gfx/",
            loaderSpeed = 0.08,
            navOptions = {defaultSection = "system"},
            pages = {
                {name = "@i18n(app.modules.rfstatus.name)@", script = "rfstatus.lua", image = "rfstatus.png", bgtask = false, offline = false},
                {name = "@i18n(app.modules.validate_sensors.name)@", script = "sensors.lua", image = "sensors.png", bgtask = true, offline = true},
                {name = "@i18n(app.modules.fblsensors.name)@", script = "fblsensors.lua", image = "fblsensors.png", bgtask = true, offline = false},
                {name = "@i18n(app.modules.fblstatus.name)@", script = "fblstatus.lua", image = "fblstatus.png", bgtask = true, offline = false},
                {name = "@i18n(app.modules.info.name)@", script = "info.lua", image = "info.png", bgtask = true, offline = true}
            }
        },
        governor = {
            title = "@i18n(app.modules.governor.name)@",
            scriptPrefix = "governor/tools/",
            iconPrefix = "app/modules/governor/gfx/",
            loaderSpeed = "DEFAULT",
            navOptions = {defaultSection = "mechanics", showProgress = true},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            hooksScript = "app/modules/governor/menu_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.governor.menu_general)@", script = "general.lua", image = "general.png"},
                {name = "@i18n(app.modules.governor.menu_time)@", script = "time.lua", image = "time.png"},
                {name = "@i18n(app.modules.governor.menu_filters)@", script = "filters.lua", image = "filters.png"},
                {name = "@i18n(app.modules.governor.menu_curves)@", script = "curves.lua", image = "curves.png"}
            }
        },
        profile_governor = {
            title = "@i18n(app.modules.profile_governor.name)@",
            scriptPrefix = "profile_governor/tools/",
            iconPrefix = "app/modules/governor/gfx/",
            loaderSpeed = "DEFAULT",
            navOptions = {showProgress = true},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            hooksScript = "app/modules/profile_governor/menu_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.governor.menu_general)@", script = "general.lua", image = "general.png"},
                {name = "@i18n(app.modules.governor.menu_flags)@", script = "flags.lua", image = "flags.png"}
            }
        },
        blackbox = {
            title = "@i18n(app.modules.blackbox.name)@",
            scriptPrefix = "blackbox/tools/",
            iconPrefix = "app/modules/blackbox/gfx/",
            loaderSpeed = "DEFAULT",
            navOptions = {defaultSection = "safety"},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = true},
            hooksScript = "app/modules/blackbox/menu_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.blackbox.menu_configuration)@", script = "configuration.lua", image = "configuration.png"},
                {name = "@i18n(app.modules.blackbox.menu_logging)@", script = "logging.lua", image = "logging.png"},
                {name = "@i18n(app.modules.blackbox.menu_status)@", script = "status.lua", image = "status.png"}
            }
        },
        beepers = {
            title = "@i18n(app.modules.beepers.name)@",
            scriptPrefix = "beepers/tools/",
            iconPrefix = "app/modules/beepers/gfx/",
            loaderSpeed = "DEFAULT",
            navOptions = {defaultSection = "safety"},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = true},
            hooksScript = "app/modules/beepers/menu_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.beepers.menu_configuration)@", script = "configuration.lua", image = "configuration.png"},
                {name = "@i18n(app.modules.beepers.menu_dshot)@", script = "dshot.lua", image = "dshot.png"}
            }
        },
        mixer = {
            title = "@i18n(app.modules.mixer.name)@",
            scriptPrefix = "mixer/tools/",
            iconPrefix = "app/modules/mixer/gfx/",
            loaderSpeed = "DEFAULT",
            navOptions = {defaultSection = "mechanics", showProgress = true},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            hooksScript = "app/modules/mixer/menu_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.mixer.swash)@", script = "swash.lua", image = "swash.png", apiversion = {12, 0, 9}},
                {name = "@i18n(app.modules.mixer.swash)@", script = "swash_legacy.lua", image = "swash.png", apiversionlt = {12, 0, 9}},
                {name = "@i18n(app.modules.mixer.geometry)@", script = "swashgeometry.lua", image = "geometry.png", apiversion = {12, 0, 9}},
                {name = "@i18n(app.modules.mixer.tail)@", script = "tail.lua", image = "tail.png", apiversion = {12, 0, 9}},
                {name = "@i18n(app.modules.mixer.tail)@", script = "tail_legacy.lua", image = "tail.png", apiversionlt = {12, 0, 9}},
                {name = "@i18n(app.modules.mixer.trims)@", script = "trims.lua", image = "trims.png"}
            }
        },
        servos_type = {
            moduleKey = "servos_type",
            title = "@i18n(app.modules.servos.name)@",
            scriptPrefix = "servos/tools/",
            iconPrefix = "app/modules/servos/gfx/",
            loaderSpeed = "DEFAULT",
            navOptions = {defaultSection = "mechanics", showProgress = true},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            hooksScript = "app/modules/servos/menu_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.servos.pwm)@", script = "pwm.lua", image = "pwm.png"},
                {name = "@i18n(app.modules.servos.bus)@", script = "bus.lua", image = "bus.png"}
            }
        },
        rates_advanced = {
            title = "@i18n(app.modules.rates_advanced.name)@",
            scriptPrefix = "rates_advanced/tools/",
            iconPrefix = "app/modules/rates_advanced/gfx/",
            loaderSpeed = "DEFAULT",
            navOptions = {defaultSection = "flight_tuning", showProgress = true},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            hooksScript = "app/modules/rates_advanced/menu_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.rates_advanced.advanced)@", script = "advanced.lua", image = "advanced.png"},
                {name = "@i18n(app.modules.rates_advanced.table)@", script = "table.lua", image = "table.png"}
            }
        },
        settings_admin = {
            title = "@i18n(app.modules.settings.name)@",
            scriptPrefix = "settings/tools/",
            iconPrefix = "app/modules/settings/gfx/",
            loaderSpeed = 0.08,
            navOptions = {defaultSection = "system", showProgress = true},
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            pages = {
                {name = "@i18n(app.modules.settings.txt_general)@", script = "general.lua", image = "general.png", offline = true},
                {name = "@i18n(app.modules.settings.dashboard)@", script = "dashboard.lua", image = "dashboard.png", offline = true},
                {name = "@i18n(app.modules.settings.localizations)@", script = "localizations.lua", image = "localizations.png", offline = true},
                {name = "@i18n(app.modules.settings.audio)@", script = "audio.lua", image = "audio.png", offline = true}
            }
        },
        settings_dashboard = {
            moduleKey = "settings_dashboard",
            title = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.dashboard)@",
            scriptPrefix = "settings/tools/",
            iconPrefix = "app/modules/settings/gfx/",
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            navOptions = {defaultSection = "system", showProgress = true},
            hooksScript = "app/modules/settings/tools/dashboard_hooks.lua",
            pages = {
                {name = "@i18n(app.modules.settings.dashboard_theme)@", script = "dashboard_theme.lua", image = "dashboard_theme.png", offline = true},
                {name = "@i18n(app.modules.settings.dashboard_settings)@", script = "dashboard_settings.lua", image = "dashboard_settings.png", offline = false}
            }
        },
        settings_dashboard_audio = {
            moduleKey = "settings_dashboard_audio",
            title = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@",
            scriptPrefix = "settings/tools/",
            iconPrefix = "app/modules/settings/gfx/",
            navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
            navOptions = {defaultSection = "system", showProgress = true},
            pages = {
                {name = "@i18n(app.modules.settings.txt_audio_events)@", script = "audio_events.lua", image = "audio_events.png", offline = true},
                {name = "@i18n(app.modules.settings.txt_audio_switches)@", script = "audio_switches.lua", image = "audio_switches.png", offline = true},
                {name = "@i18n(app.modules.settings.txt_audio_timer)@", script = "audio_timer.lua", image = "audio_timer.png", offline = true}
            }
        }
    }
}
