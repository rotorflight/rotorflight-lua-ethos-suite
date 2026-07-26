-- Rotorflight system tool.
--
-- Wires together the menu tree (app/menu_container.lua), the
-- return-context stack that makes Back correct at any depth
-- (app/navigation.lua), and Ethos's own physical-Back-key event, then
-- gets out of the way -- app/menu_container.lua does the actual screen
-- building, and each page (e.g. app/pages/pids.lua, app/pages/
-- pid_controller.lua) owns its own form once opened. Following
-- rotorflight-lua-ethos-suite's navigation structure, trimmed to this
-- rebuild's still-small page count; see the comments in
-- app/menu_container.lua for exactly what was cut.
--
-- Owns its own private state. It does not read or write the dashboard
-- widget's or background task's state; the only cross-subsystem talking
-- it does is via lib/bus.lua's "msp.request" topic, and only indirectly,
-- via whichever page is currently open.

local navigation = assert(loadfile("app/navigation.lua"))()
local menuContainer = assert(loadfile("app/menu_container.lua"))()
local memstats = assert(loadfile("lib/memstats.lua"))()
local bus = assert(loadfile("lib/bus.lua"))()
local escProtocolGuard = assert(loadfile("app/esc_protocol_guard.lua"))()
local servoBusGuard = assert(loadfile("app/servo_bus_guard.lua"))()
local settingsStore = assert(loadfile("lib/settings_store.lua"))()

local developerModeEnabled = false

local APP_SESSION_PACKAGE_KEYS = {
  "rfsuite.app.pages.esc_forward_4way",
  "rfsuite.app.pages.esc_forward_vendor",
}

-- This tool's top-level tile list, and the submenu tree it opens into.
-- Both mirror the real menu tree in rotorflight-lua-ethos-suite's own
-- app/modules/manifest.lua -- reviewed directly rather than re-derived,
-- so pages land in the same place a pilot already familiar with that
-- suite would expect, without reusing any of that project's actual
-- module code. `group` renders as a section label above its tile row
-- (see app/menu_container.lua) -- matching that suite's own section
-- labels ("Configuration", "System").
--
-- **Root screen is "Configuration", not a flat tile list** -- corrected
-- after a live screenshot of the original's own actual root showed two
-- section groups: "Configuration" (Flight Tuning, Setup) and "System"
-- (Tools, Logs, Settings, Developer), not PIDs/Rates/Governor/Advanced
-- sitting directly at the top level the way an earlier version of this
-- rebuild had them (before the manifest was reviewed this closely).
-- ROOT_ENTRIES now has all 6 of the original's own root tiles, matching
-- its section grouping/order exactly -- "Flight Tuning" is one of two
-- with a real destination (MENUS.flight_tuning_menu, which holds what
-- used to be ROOT_ENTRIES itself: PIDs/Rates/Governor/Advanced,
-- unchanged relative order); "Setup" is the other, now that
-- MENUS.setup_menu has its own first real entry (Configuration -- see
-- app/pages/configuration.lua). The remaining 4 (Tools, Logs, Settings,
-- Developer) are **scaffolded, not built**: each opens an empty tile
-- screen (just the header + Back, via its own zero-entry MENUS.*_menu
-- below) rather than a dead/crashing tile or a placeholder page file,
-- since none of those modules exist in this rebuild yet -- add real
-- entries to the matching *_menu table below as each one actually gets
-- built, same structure-only convention as everywhere else in this
-- file. (The original's own Logs/Developer tiles are single leaf pages,
-- not submenus -- using an empty submenu placeholder for those two as
-- well, rather than a dummy page file, keeps every still-scaffolded tile
-- uniform until there's real content behind it. Setup's own remaining 10
-- entries -- Radio Config, Telemetry, Accelerometer, Alignment, Ports,
-- Mixer, Servos, Controls, Power, ESC & Motors, Governor -- are
-- similarly still unbuilt; MENUS.setup_menu just isn't *entirely* empty
-- any more.)
-- Tile titles reuse the exact same i18n tag each page uses for its own
-- PAGE_TITLE (e.g. app/pages/pids.lua) rather than a separate literal --
-- i18n tags resolve via build-time text substitution (see
-- .vscode/scripts/resolve_i18n_tags.py), so every occurrence of the same
-- tag always resolves identically; two different literals for "the same
-- name" could silently drift out of sync with each other.
local ROOT_ENTRIES = {
  {title = "@i18n(app.menu_section_flight_tuning)@", icon = lcd.loadMask("app/gfx/flight_tuning.png"), menuId = "flight_tuning_menu", group = "@i18n(app.header_configuration)@"},
  {title = "@i18n(app.modules.hardware_setup.name)@", icon = lcd.loadMask("app/gfx/hardware.png"), menuId = "setup_menu", group = "@i18n(app.header_configuration)@"},
  {title = "@i18n(app.menu_section_tools)@", icon = lcd.loadMask("app/gfx/tools.png"), menuId = "tools_menu", group = "@i18n(app.header_system)@"},
  {title = "@i18n(app.modules.logs.name)@", icon = lcd.loadMask("app/gfx/logs.png"), script = "app/pages/logs.lua", group = "@i18n(app.header_system)@", offline = true},
  {title = "@i18n(app.modules.settings.name)@", icon = lcd.loadMask("app/gfx/settings.png"), menuId = "settings_menu", group = "@i18n(app.header_system)@", offline = true},
}

-- {menuId -> {title=, entries={...}}} -- see app/menu_container.lua's
-- menuId handling.
local MENUS = {
  -- Setup has started growing real entries (Configuration, Radio Config,
  -- Telemetry, Accelerometer, Alignment, Ports, Mixer, Servos, Controls,
  -- Power, ESC & Motors, Governor) -- see
  -- ROOT_ENTRIES' own comment for why the other 4 root tiles
  -- (Tools/Logs/Settings/Developer) stay empty placeholders for now too.
  setup_menu = {
    title = "@i18n(app.modules.hardware_setup.name)@",
    entries = {
      {title = "@i18n(app.modules.configuration.name)@", icon = lcd.loadMask("app/gfx/configuration.png"), script = "app/pages/configuration.lua"},
      {title = "@i18n(app.modules.radio_config.name)@", icon = lcd.loadMask("app/gfx/radio_config.png"), script = "app/pages/radio_config.lua"},
      {title = "@i18n(app.modules.telemetry.name)@", icon = lcd.loadMask("app/gfx/telemetry.png"), script = "app/pages/telemetry.lua"},
      {title = "@i18n(app.modules.accelerometer.name)@", icon = lcd.loadMask("app/gfx/accelerometer.png"), script = "app/pages/accelerometer.lua"},
      {title = "@i18n(app.modules.alignment.name)@", icon = lcd.loadMask("app/gfx/alignment.png"), script = "app/pages/alignment.lua"},
      {title = "@i18n(app.modules.ports.name)@", icon = lcd.loadMask("app/gfx/ports.png"), script = "app/pages/ports.lua"},
      {title = "@i18n(app.modules.mixer.name)@", icon = lcd.loadMask("app/gfx/mixer.png"), menuId = "mixer_menu"},
      {title = "@i18n(app.modules.servos.name)@", icon = lcd.loadMask("app/gfx/servos.png"), menuId = "servos_menu"},
      {title = "@i18n(app.menu_section_controls)@", icon = lcd.loadMask("app/gfx/controls.png"), menuId = "controls_menu"},
      {title = "@i18n(app.modules.power.name)@", icon = lcd.loadMask("app/gfx/power.png"), menuId = "power_menu"},
      {title = "@i18n(app.modules.esc_motors.name)@", icon = lcd.loadMask("app/gfx/esc_motors.png"), menuId = "esc_motors_menu"},
      {title = "@i18n(app.modules.governor.name)@", icon = lcd.loadMask("app/gfx/setup_governor.png"), menuId = "setup_governor_menu"},
    },
  },
  mixer_menu = {
    title = "@i18n(app.modules.mixer.name)@",
    entries = {
      {title = "@i18n(app.modules.mixer.swash)@", icon = lcd.loadMask("app/gfx/mixer_swash.png"), script = "app/pages/mixer_swash.lua"},
      {title = "@i18n(app.modules.mixer.geometry)@", icon = lcd.loadMask("app/gfx/mixer_geometry.png"), script = "app/pages/mixer_geometry.lua"},
      {title = "@i18n(app.modules.mixer.tail)@", icon = lcd.loadMask("app/gfx/mixer_tail.png"), script = "app/pages/mixer_tail.lua"},
      {title = "@i18n(app.modules.mixer.trims)@", icon = lcd.loadMask("app/gfx/mixer_trims.png"), script = "app/pages/mixer_trims.lua"},
    },
  },
  servos_menu = {
    title = "@i18n(app.modules.servos.name)@",
    entries = {
      {title = "@i18n(app.modules.servos.pwm)@", icon = lcd.loadMask("app/gfx/servos_pwm.png"), script = "app/pages/servos_pwm.lua"},
      {title = "@i18n(app.modules.servos.bus)@", icon = lcd.loadMask("app/gfx/servos_bus.png"), script = "app/pages/servos_bus.lua", requiresServoBus = true},
    },
  },
  controls_menu = {
    title = "@i18n(app.menu_section_controls)@",
    entries = {
      {title = "@i18n(app.modules.modes.name)@", icon = lcd.loadMask("app/gfx/modes.png"), script = "app/pages/modes.lua"},
      {title = "@i18n(app.modules.adjustments.name)@", icon = lcd.loadMask("app/gfx/adjustments.png"), script = "app/pages/adjustments.lua"},
      {title = "@i18n(app.modules.failsafe.name)@", icon = lcd.loadMask("app/gfx/failsafe.png"), script = "app/pages/failsafe.lua"},
      {title = "@i18n(app.modules.beepers.name)@", icon = lcd.loadMask("app/gfx/beepers.png"), menuId = "beepers_menu"},
      {title = "@i18n(app.modules.blackbox.name)@", icon = lcd.loadMask("app/gfx/blackbox.png"), menuId = "blackbox_menu"},
      {title = "@i18n(app.modules.stats.name)@", icon = lcd.loadMask("app/gfx/stats.png"), script = "app/pages/stats.lua"},
    },
  },
  beepers_menu = {
    title = "@i18n(app.modules.beepers.name)@",
    entries = {
      {title = "@i18n(app.modules.beepers.menu_configuration)@", icon = lcd.loadMask("app/gfx/beepers_configuration.png"), script = "app/pages/beepers_configuration.lua"},
      {title = "@i18n(app.modules.beepers.menu_dshot)@", icon = lcd.loadMask("app/gfx/beepers_dshot.png"), script = "app/pages/beepers_dshot.lua"},
    },
  },
  blackbox_menu = {
    title = "@i18n(app.modules.blackbox.name)@",
    entries = {
      {title = "@i18n(app.modules.blackbox.menu_configuration)@", icon = lcd.loadMask("app/gfx/blackbox_configuration.png"), script = "app/pages/blackbox_configuration.lua"},
      {title = "@i18n(app.modules.blackbox.menu_logging)@", icon = lcd.loadMask("app/gfx/blackbox_logging.png"), script = "app/pages/blackbox_logging.lua"},
      {title = "@i18n(app.modules.blackbox.menu_status)@", icon = lcd.loadMask("app/gfx/blackbox_status.png"), script = "app/pages/blackbox_status.lua"},
    },
  },
  power_menu = {
    title = "@i18n(app.modules.power.name)@",
    entries = {
      {title = "@i18n(app.modules.power.battery_name)@", icon = lcd.loadMask("app/gfx/power_battery.png"), script = "app/pages/power_battery.lua"},
      {title = "@i18n(app.modules.power.alert_name)@", icon = lcd.loadMask("app/gfx/power.png"), script = "app/pages/power_alerts.lua"},
      {title = "@i18n(app.modules.power.source_name)@", icon = lcd.loadMask("app/gfx/power_source.png"), script = "app/pages/power_source.lua"},
      {title = "@i18n(app.modules.power.smartfuel_name)@", icon = lcd.loadMask("app/gfx/power_smartfuel.png"), script = "app/pages/power_smartfuel.lua"},
    },
  },
  esc_motors_menu = {
    title = "@i18n(app.modules.esc_motors.name)@",
    entries = {
      {title = "@i18n(app.modules.esc_motors.throttle)@", icon = lcd.loadMask("app/gfx/esc_motors_throttle.png"), script = "app/pages/esc_motors_throttle.lua"},
      {title = "@i18n(app.modules.esc_motors.telemetry)@", icon = lcd.loadMask("app/gfx/esc_motors_telemetry.png"), script = "app/pages/esc_motors_telemetry.lua"},
      {title = "@i18n(app.modules.esc_motors.rpm)@", icon = lcd.loadMask("app/gfx/esc_motors_rpm.png"), script = "app/pages/esc_motors_rpm.lua"},
      {title = "@i18n(app.modules.esc_tools.name)@", icon = lcd.loadMask("app/gfx/esc_tools.png"), menuId = "esc_forward_menu"},
    },
  },
  esc_forward_menu = {
    title = "@i18n(app.modules.esc_tools.name)@",
    entries = {
      {title = "@i18n(app.modules.esc_tools.mfg.hw5.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_hw5.png"), script = "app/pages/esc_forward_hw5.lua", escProtocolId = 3},
      {title = "@i18n(app.modules.esc_tools.mfg.am32.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_am32.png"), script = "app/pages/esc_forward_am32.lua", escProtocolId = 1},
      {title = "@i18n(app.modules.esc_tools.mfg.blheli_s.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_blheli_s.png"), script = "app/pages/esc_forward_blheli_s.lua", escProtocolId = 1},
      {title = "@i18n(app.modules.esc_tools.mfg.bluejay.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_bluejay.png"), script = "app/pages/esc_forward_bluejay.lua", escProtocolId = 1},
      {title = "@i18n(app.modules.esc_tools.mfg.flrtr.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_flyrotor.png"), script = "app/pages/esc_forward_flyrotor.lua", escProtocolId = 10},
      {title = "@i18n(app.modules.esc_tools.mfg.omp.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_omp.png"), script = "app/pages/esc_forward_omp.lua", escProtocolId = 6},
      {title = "@i18n(app.modules.esc_tools.mfg.scorp.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_scorpion.png"), script = "app/pages/esc_forward_scorpion.lua", escProtocolId = 4},
      {title = "@i18n(app.modules.esc_tools.mfg.xdfly.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_xdfly.png"), script = "app/pages/esc_forward_xdfly.lua", escProtocolId = 12},
      {title = "@i18n(app.modules.esc_tools.mfg.yge.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_yge.png"), script = "app/pages/esc_forward_yge.lua", escProtocolId = 9},
      {title = "@i18n(app.modules.esc_tools.mfg.ztw.name)@", icon = lcd.loadMask("app/gfx/esc_mfg_ztw.png"), script = "app/pages/esc_forward_ztw.lua", escProtocolId = 7},
    },
  },
  setup_governor_menu = {
    title = "@i18n(app.modules.governor.name)@",
    entries = {
      {title = "@i18n(app.modules.governor.menu_general)@", icon = lcd.loadMask("app/gfx/setup_governor_general.png"), script = "app/pages/setup_governor_general.lua"},
      {title = "@i18n(app.modules.governor.menu_time)@", icon = lcd.loadMask("app/gfx/setup_governor_time.png"), script = "app/pages/setup_governor_time.lua"},
      {title = "@i18n(app.modules.governor.menu_filters)@", icon = lcd.loadMask("app/gfx/setup_governor_filters.png"), script = "app/pages/setup_governor_filters.lua"},
      {title = "@i18n(app.modules.governor.menu_curves)@", icon = lcd.loadMask("app/gfx/setup_governor_curves.png"), script = "app/pages/setup_governor_curves.lua"},
    },
  },
  tools_menu = {
    title = "@i18n(app.menu_section_tools)@",
    entries = {
      {title = "@i18n(app.modules.copyprofiles.name)@", icon = lcd.loadMask("app/gfx/copy_profiles.png"), script = "app/pages/copy_profiles.lua"},
      {title = "@i18n(app.modules.profile_select.name)@", icon = lcd.loadMask("app/gfx/profile_select.png"), script = "app/pages/profile_select.lua"},
      {title = "@i18n(app.modules.diagnostics.name)@", icon = lcd.loadMask("app/gfx/diagnostics.png"), menuId = "diagnostics_menu"},
      {title = "@i18n(app.modules.settings.txt_developer)@", icon = lcd.loadMask("app/gfx/developer.png"), menuId = "developer_menu", visibleWhen = function() return developerModeEnabled == true end},
    },
  },
  diagnostics_menu = {
    title = "@i18n(app.modules.diagnostics.name)@",
    entries = {
      {title = "@i18n(app.modules.rfstatus.name)@", icon = lcd.loadMask("app/gfx/diagnostics_rfstatus.png"), script = "app/pages/diagnostics_rfstatus.lua"},
      {title = "@i18n(app.modules.elrs_telemetry.name)@", icon = lcd.loadMask("app/gfx/diagnostics_elrs_link.png"), script = "app/pages/diagnostics_elrs_link.lua"},
      {title = "@i18n(app.modules.fblstatus.name)@", icon = lcd.loadMask("app/gfx/diagnostics_fblstatus.png"), script = "app/pages/diagnostics_fblstatus.lua"},
      {title = "@i18n(app.modules.info.name)@", icon = lcd.loadMask("app/gfx/diagnostics_info.png"), script = "app/pages/diagnostics_info.lua"},
    },
  },
  logs_menu = {title = "@i18n(app.modules.logs.name)@", entries = {}},
  settings_menu = {
    title = "@i18n(app.modules.settings.name)@",
    entries = {
      {title = "@i18n(app.modules.settings.dashboard)@", icon = lcd.loadMask("app/gfx/settings_dashboard.png"), menuId = "settings_dashboard_menu", offline = true},
      {title = "ActiveLook", icon = lcd.loadMask("app/gfx/settings_activelook.png"), menuId = "settings_activelook_menu", offline = true},
      {title = "@i18n(app.modules.settings.audio)@", icon = lcd.loadMask("app/gfx/settings_audio.png"), menuId = "settings_audio_menu", offline = true},
      {title = "@i18n(app.modules.settings.txt_developer)@", icon = lcd.loadMask("app/gfx/developer.png"), script = "app/pages/developer_logging.lua", offline = true},
    },
  },
  settings_dashboard_menu = {
    title = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.dashboard)@",
    entries = {
      {title = "@i18n(app.modules.settings.dashboard_theme)@", icon = lcd.loadMask("app/gfx/settings_dashboard_theme.png"), script = "app/pages/settings_dashboard_theme.lua", offline = true},
      {title = "@i18n(app.modules.settings.dashboard_settings)@", icon = lcd.loadMask("app/gfx/settings_dashboard_settings.png"), script = "app/pages/settings_dashboard_settings.lua", offline = true},
    },
  },
  settings_activelook_menu = {
    title = "@i18n(app.modules.settings.name)@ / ActiveLook",
    entries = {
      {title = "@i18n(app.modules.settings.activelook_settings)@", icon = lcd.loadMask("app/gfx/settings_activelook_settings.png"), script = "app/pages/settings_activelook_settings.lua", offline = true},
      {title = "@i18n(app.modules.settings.activelook_preflight)@", icon = lcd.loadMask("app/gfx/settings_activelook_preflight.png"), script = "app/pages/settings_activelook_preflight.lua", offline = true},
      {title = "@i18n(app.modules.settings.activelook_inflight)@", icon = lcd.loadMask("app/gfx/settings_activelook_inflight.png"), script = "app/pages/settings_activelook_inflight.lua", offline = true},
      {title = "@i18n(app.modules.settings.activelook_postflight)@", icon = lcd.loadMask("app/gfx/settings_activelook_postflight.png"), script = "app/pages/settings_activelook_postflight.lua", offline = true},
    },
  },
  settings_audio_menu = {
    title = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@",
    entries = {
      {title = "@i18n(app.modules.settings.txt_audio_events)@", icon = lcd.loadMask("app/gfx/settings_audio_events.png"), script = "app/pages/settings_audio_events.lua", offline = true},
      {title = "@i18n(app.modules.settings.txt_audio_switches)@", icon = lcd.loadMask("app/gfx/settings_audio_switches.png"), script = "app/pages/settings_audio_switches.lua", offline = true},
      {title = "@i18n(app.modules.settings.txt_audio_timer)@", icon = lcd.loadMask("app/gfx/settings_audio_timer.png"), script = "app/pages/settings_audio_timer.lua", offline = true},
    },
  },
  developer_menu = {
    title = "@i18n(app.modules.settings.txt_developer)@",
    entries = {
      {title = "@i18n(app.modules.msp_speed.name)@", icon = lcd.loadMask("app/gfx/developer_msp_speed.png"), script = "app/pages/developer_msp_speed.lua"},
      {title = "@i18n(app.modules.msp_exp.name)@", icon = lcd.loadMask("app/gfx/developer_msp_exp.png"), script = "app/pages/developer_msp_exp.lua"},
    },
  },
  -- Matches the original's own `flight_tuning_menu` manifest entry --
  -- every entry now exists (PIDs, Rates, Governor, Advanced). This used
  -- to be ROOT_ENTRIES itself, flattened onto the tool's true root --
  -- see that variable's own comment above for why it moved one level
  -- deeper. No `group` needed on these entries any more (unlike when
  -- they lived at the root) -- this menu's own `title` below already
  -- becomes the screen header when opened via `menuId`.
  flight_tuning_menu = {
    title = "@i18n(app.menu_section_flight_tuning)@",
    entries = {
      {title = "@i18n(app.modules.pids.name)@", icon = lcd.loadMask("app/gfx/pids.png"), script = "app/pages/pids.lua"},
      {title = "@i18n(app.modules.rates.name)@", icon = lcd.loadMask("app/gfx/rates.png"), script = "app/pages/rates.lua"},
      {title = "@i18n(app.modules.governor.name)@", icon = lcd.loadMask("app/gfx/governor.png"), menuId = "governor_menu"},
      {title = "@i18n(app.menu_section_advanced)@", icon = lcd.loadMask("app/gfx/advanced.png"), menuId = "advanced_menu"},
    },
  },
  -- Matches the original's own app/modules/manifest.lua `advanced_menu` --
  -- every entry now exists (Filters, PID Controller, PID Bandwidth,
  -- Autolevel, Main Rotor, Tail Rotor, Rescue, Rates Advanced). Relative
  -- order still matches the manifest's own ordering.
  advanced_menu = {
    title = "@i18n(app.menu_section_advanced)@",
    entries = {
      {title = "@i18n(app.modules.filters.name)@", icon = lcd.loadMask("app/gfx/filters.png"), script = "app/pages/filters.lua"},
      {title = "@i18n(app.modules.pid_controller.name)@", icon = lcd.loadMask("app/gfx/pid_controller.png"), script = "app/pages/pid_controller.lua"},
      {title = "@i18n(app.modules.pid_bandwidth.name)@", icon = lcd.loadMask("app/gfx/pid_bandwidth.png"), script = "app/pages/pid_bandwidth.lua"},
      {title = "@i18n(app.modules.autolevel.name)@", icon = lcd.loadMask("app/gfx/autolevel.png"), script = "app/pages/autolevel.lua"},
      {title = "@i18n(app.modules.main_rotor.name)@", icon = lcd.loadMask("app/gfx/main_rotor.png"), script = "app/pages/main_rotor.lua"},
      {title = "@i18n(app.modules.tail_rotor.name)@", icon = lcd.loadMask("app/gfx/tail_rotor.png"), script = "app/pages/tail_rotor.lua"},
      {title = "@i18n(app.modules.rescue.name)@", icon = lcd.loadMask("app/gfx/rescue.png"), script = "app/pages/rescue.lua"},
      {title = "@i18n(app.modules.rates_advanced.name)@", icon = lcd.loadMask("app/gfx/rates_advanced.png"), menuId = "rates_advanced_menu"},
    },
  },
  -- Matches the original's own `profile_governor` manifest entry
  -- (General, Flags) -- both now exist as real pages.
  governor_menu = {
    title = "@i18n(app.modules.governor.name)@",
    entries = {
      {title = "@i18n(app.modules.governor.menu_general)@", icon = lcd.loadMask("app/gfx/governor_general.png"), script = "app/pages/governor_general.lua"},
      {title = "@i18n(app.modules.governor.menu_flags)@", icon = lcd.loadMask("app/gfx/governor_flags.png"), script = "app/pages/governor_flags.lua"},
    },
  },
  -- Matches the original's own `rates_advanced` manifest entry --
  -- every entry now exists (Advanced, Cyclic Behaviour, Rate Table).
  -- app/pages/rates_type.lua is the *only* place rates_type can be
  -- changed, matching the original's own page separation -- see its
  -- header comment and app/pages/rates.lua's own for why.
  rates_advanced_menu = {
    title = "@i18n(app.modules.rates_advanced.name)@",
    entries = {
      {title = "@i18n(app.modules.rates_advanced.menu_advanced)@", icon = lcd.loadMask("app/gfx/rates_advanced_grid.png"), script = "app/pages/rates_advanced.lua"},
      {title = "@i18n(app.modules.rates_advanced.cyclic_behaviour)@", icon = lcd.loadMask("app/gfx/rates_cyclic.png"), script = "app/pages/rates_cyclic.lua"},
      {title = "@i18n(app.modules.rates_advanced.rate_table)@", icon = lcd.loadMask("app/gfx/rates_type.png"), script = "app/pages/rates_type.lua"},
    },
  },
}

local nav = navigation.new()
local currentEventHandler = nil
local currentCleanupHandler = nil
local currentPaintHandler = nil
-- Forwards this tool's own registered `wakeup` (called by Ethos on every
-- tick while THIS tool owns the screen) to whichever page is currently
-- open -- see app/pages/pids.lua's use of this for why a page needs it:
-- form.openProgressDialog() only works reliably when called from here, not
-- from a callback nested inside the background task's own wakeup (even
-- though lib/bus.lua's pub/sub technically runs in the same Lua state,
-- Ethos still distinguishes "the active tool's own tick" from "some other
-- subsystem's callback chain" for spawning new UI like a modal dialog).
local currentWakeupHandler = nil

local TASK_STATUS_TIMEOUT = 1.5
local TASK_ALERT_GRACE = 0.75
local TASK_ALERT_TITLE = "@i18n(app.msg_background_task_missing_title)@"
local TASK_ALERT_BODY = "@i18n(app.msg_background_task_missing_body)@"
local BTN_OK = "@i18n(app.btn_ok)@"

local appOpenedAt = nil
local taskStatusAt = nil
local sessionConnected = false
local taskAlertPending = false
local taskAlertOpen = false
local taskAlertShown = false

local function isBackgroundTaskRunning()
  return taskStatusAt ~= nil and (os.clock() - taskStatusAt) <= TASK_STATUS_TIMEOUT
end

local function backgroundTaskGraceExpired()
  return appOpenedAt ~= nil and (os.clock() - appOpenedAt) >= TASK_ALERT_GRACE
end

local function requestBackgroundTaskAlert()
  if taskAlertOpen or taskAlertShown then return end
  taskAlertPending = true
end

local function showBackgroundTaskAlert()
  if not taskAlertPending or taskAlertOpen or taskAlertShown then return end
  taskAlertPending = false
  taskAlertOpen = true
  taskAlertShown = true
  form.openDialog({
    title = TASK_ALERT_TITLE,
    message = TASK_ALERT_BODY,
    buttons = {
      {label = BTN_OK, action = function()
        taskAlertOpen = false
        return true
      end},
    },
    wakeup = function() end,
    paint = function() end,
    options = TEXT_LEFT,
  })
end

local taskGuard = {
  isRunning = isBackgroundTaskRunning,
  isConnected = function() return sessionConnected == true end,
  graceExpired = backgroundTaskGraceExpired,
  requestAlert = requestBackgroundTaskAlert,
}

MENUS.esc_forward_menu.guard = escProtocolGuard.new({
  canRequest = function()
    return isBackgroundTaskRunning() and sessionConnected == true
  end,
})

MENUS.servos_menu.guard = servoBusGuard.new({
  canRequest = function()
    return isBackgroundTaskRunning() and sessionConnected == true
  end,
})

bus.subscribe("task.status", function(status)
  if status and status.running then
    taskStatusAt = tonumber(status.updatedAt) or os.clock()
    taskAlertPending = false
    taskAlertShown = false
  end
end)

bus.subscribe("session.update", function(session)
  sessionConnected = session and session.connected == true
end)

local function updateDeveloperMode(settings)
  developerModeEnabled = settingsStore.developerModeEnabled(settings or settingsStore.load())
end

bus.subscribe("settings.update", updateDeveloperMode)

local function setEventHandler(handler)
  currentEventHandler = handler
end

local function setWakeupHandler(handler)
  currentWakeupHandler = handler
end

local function setPaintHandler(handler)
  currentPaintHandler = handler
end

local function setCleanupHandler(handler)
  currentCleanupHandler = handler
end

local function create()
  appOpenedAt = os.clock()
  taskAlertPending = false
  taskAlertOpen = false
  taskAlertShown = false
  updateDeveloperMode()
  menuContainer.openRoot(nav, ROOT_ENTRIES, setEventHandler, setWakeupHandler, setPaintHandler, setCleanupHandler, MENUS, taskGuard)
  return {}
end

local function wakeup(state)
  if currentWakeupHandler then
    currentWakeupHandler()
  end
  showBackgroundTaskAlert()
end

local function paint(state)
  if currentPaintHandler then
    currentPaintHandler()
  end
end

-- Forwards the physical Back/Close key to whatever screen is currently
-- open (see app/menu_container.lua's setEventHandler calls). At the root
-- menu no handler is installed, so this returns false and Ethos falls
-- through to its own default (closing the tool).
local function event(state, category, value, x, y)
  if currentEventHandler then
    return currentEventHandler(category, value) == true
  end
  return false
end

-- Prints before/after cleanup so the "after" figure reflects a real
-- collectgarbage("collect") -- matching rotorflight-lua-ethos-suite's own
-- app.close() (which also forces a full collect right before exiting) --
-- rather than whatever incremental garbage happened to still be pending.
-- Do not call form.clear() here: on real Ethos the tool close callback can
-- run after form mutation has already been forbidden, and Ethos owns final
-- form teardown during app exit.
local function close(state)
  memstats.print("app.close (start)")
  if currentCleanupHandler then
    currentCleanupHandler()
    currentCleanupHandler = nil
  end
  nav.clear()
  setEventHandler(nil)
  setWakeupHandler(nil)
  setPaintHandler(nil)
  for _, key in ipairs(APP_SESSION_PACKAGE_KEYS) do
    package.loaded[key] = nil
  end
  collectgarbage("collect")
  memstats.print("app.close (end)")
end

local tool = {
  name = "Rotorflight",
  icon = lcd.loadMask("app/gfx/icon.png"),
  create = create,
  wakeup = wakeup,
  paint = paint,
  event = event,
  close = close,
}

local function init()
  return system.registerSystemTool(tool)
end

return {init = init}
