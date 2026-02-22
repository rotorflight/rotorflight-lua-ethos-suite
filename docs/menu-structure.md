# Menu Structure


## Main Menu

### Configuration
- Flight Tuning (menuId `flight_tuning_menu`)
  - menuId `flight_tuning_menu`: Flight Tuning
    - PIDs (script `pids/pids.lua`)
    - Rates (script `rates/rates.lua`)
    - Governor (script `profile_governor/governor.lua`)
      - variants: >= 12.0.9 => `profile_governor/governor.lua`; < 12.0.9 => `profile_governor/governor_legacy.lua`; default => `profile_governor/governor_legacy.lua`
      - menuId `profile_governor`: Governor
        - General (script `general.lua`)
        - Behaviour (script `flags.lua`)
    - Advanced (menuId `advanced_menu`)
      - menuId `advanced_menu`: Advanced
        - Filters (script `filters/filters.lua`)
        - PID Controller (script `profile_pidcontroller/pidcontroller.lua`)
        - PID Bandwidth (script `profile_pidbandwidth/pidbandwidth.lua`)
        - Autolevel (script `profile_autolevel/autolevel.lua`)
        - Main Rotor (script `profile_mainrotor/mainrotor.lua`)
        - Tail Rotor (script `profile_tailrotor/tailrotor.lua`)
        - Rescue (script `profile_rescue/rescue.lua`)
        - Rates (script `rates_advanced/rates_advanced.lua`)
          - menuId `rates_advanced`: Rates
            - Advanced (script `advanced.lua`)
            - Rate Table (script `table.lua`)
- Setup (menuId `setup_menu`)
  - menuId `setup_menu`: Setup
    - Configuration (script `configuration/configuration.lua`)
    - Radio Config (script `radio_config/radio_config.lua`)
    - Telemetry (script `telemetry/telemetry.lua`)
    - Accelerometer (script `accelerometer/accelerometer.lua`)
    - Alignment (script `alignment/alignment.lua`)
    - Ports (script `ports/ports.lua`)
    - Mixer (menuId `mixer`)
      - menuId `mixer`: Mixer
        - Swash (script `swash.lua` or `swash_legacy.lua`)
        - Geometry (script `swashgeometry.lua`)
        - Tail (script `tail.lua` or `tail_legacy.lua`)
        - Trims (script `trims.lua`)
    - Servos (menuId `servos_type`)
      - menuId `servos_type`: Servos
        - PWM Output (script `pwm.lua`)
        - BUS Output (script `bus.lua`)
    - Controls (menuId `safety_menu`)
      - menuId `safety_menu`: Controls
        - Modes (script `modes/modes.lua`)
        - Adjustments (script `adjustments/adjustments.lua`)
        - Failsafe (script `failsafe/failsafe.lua`)
        - Beepers (menuId `beepers`)
          - menuId `beepers`: Beepers
            - Configuration (script `configuration.lua`)
            - ESC Beacon (script `dshot.lua`)
        - Blackbox (menuId `blackbox`)
          - menuId `blackbox`: Blackbox
            - Configuration (script `configuration.lua`)
            - Logging (script `logging.lua`)
            - Status (script `status.lua`)
        - Stats (script `stats/stats.lua`)
    - Power (menuId `power`)
      - menuId `power`: Power
        - Battery (script `battery.lua`)
        - Alerts (script `alerts.lua`)
        - Sources (script `source.lua`)
    - ESC & Motors (menuId `esc_motors`)
      - menuId `esc_motors`: ESC & Motors
        - Throttle (script `throttle.lua`)
        - Telemetry (script `telemetry.lua`)
        - RPM (script `rpm.lua`)
        - ESC Tools (script `app/modules/esc_tools/tools/esc.lua`)
    - Governor (menuId `governor`)
      - menuId `governor`: Governor
        - General (script `general.lua`)
        - Ramp Time (script `time.lua`)
        - Filters (script `filters.lua`)
        - Bypass Curve (script `curves.lua`)

### System
- Tools (menuId `tools_menu`)
  - menuId `tools_menu`: Tools
    - Copy Profiles (script `copyprofiles/copyprofiles.lua`, disabled)
    - Select Profile (script `profile_select/select_profile.lua`)
    - Diagnostics (menuId `diagnostics`)
      - menuId `diagnostics`: Diagnostics
        - Status (script `rfstatus.lua`)
        - Sensors (script `sensors.lua`)
        - FBL Sensors (script `fblsensors.lua`)
        - FBL Status (script `fblstatus.lua`)
        - Info (script `info.lua`)
- Logs (module `logs`, script `logs_dir.lua`)
- Settings (menuId `settings_admin`)
  - menuId `settings_admin`: Settings
    - General (script `general.lua`)
    - Shortcuts (script `shortcuts.lua`)
    - Dashboard (script `dashboard.lua`)
      - menuId `settings_dashboard`: Settings / Dashboard
        - Theme (script `dashboard_theme.lua`)
        - Settings (script `dashboard_settings.lua`)
    - Localization (script `localizations.lua`)
    - Audio (script `audio.lua`)
      - menuId `settings_dashboard_audio`: Settings / Audio
        - Events (script `audio_events.lua`)
        - Switches (script `audio_switches.lua`)
        - Timer (script `audio_timer.lua`)
- Developer (module `developer`, script `developer.lua`)
  - menuId `developer`: Developer
    - MSP Speed (script `developer/tools/msp_speed.lua`)
    - API Tester (script `developer/tools/api_tester.lua`)
    - MSP Expermental (script `developer/tools/msp_exp.lua`)
    - Settings (script `settings/tools/development.lua`)


## Notes

- Shortcuts are user-configurable and can be shown in dock or mixed mode; they are not static manifest entries.
- Some pages have API-gated script variants; those are listed under `variants` where applicable.
