--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "@i18n(app.menu_section_hardware)@",
    loaderSpeed = "FAST",
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
        {name = "Modes", script = "modes/modes.lua", image = "app/modules/modes/modes.png", order = 14, loaderspeed = 0.05},
        {name = "@i18n(app.modules.adjustments.name)@", script = "adjustments/adjustments.lua", image = "app/modules/adjustments/adjustments.png", order = 15, loaderspeed = 0.1},
        {name = "@i18n(app.modules.filters.name)@", script = "filters/filters.lua", image = "app/modules/filters/filters.png", order = 16},
        {name = "@i18n(app.modules.power.name)@", script = "power/power.lua", image = "app/modules/power/power.png", order = 17},
        {name = "@i18n(app.modules.governor.name)@", script = "governor/governor.lua", image = "app/modules/governor/governor.png", order = 18, script_by_mspversion = {
            {">=", "12.09", "governor/governor.lua", loaderspeed = "FAST"},
            {"<", "12.09", "governor/governor_legacy.lua", loaderspeed = "SLOW"}
        }}
    }
}
