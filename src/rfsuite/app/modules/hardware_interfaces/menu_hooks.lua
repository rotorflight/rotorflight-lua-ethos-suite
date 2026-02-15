--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "@i18n(app.modules.hardware_interfaces.name)@",
    pages = {
        {name = "@i18n(app.modules.ports.name)@", script = "ports/ports.lua", image = "app/modules/ports/ports.png", loaderspeed = 0.08},
        {name = "@i18n(app.modules.telemetry.name)@", script = "telemetry/telemetry.lua", image = "app/modules/telemetry/telemetry.png"},
        {name = "@i18n(app.modules.radio_config.name)@", script = "radio_config/radio_config.lua", image = "app/modules/radio_config/radio_config.png"},
        {name = "@i18n(app.modules.beepers.name)@", script = "beepers/beepers.lua", image = "app/modules/beepers/beepers.png"},
        {name = "@i18n(app.modules.blackbox.name)@", script = "blackbox/blackbox.lua", image = "app/modules/blackbox/blackbox.png"},
        {name = "@i18n(app.modules.stats.name)@", script = "stats/stats.lua", image = "app/modules/stats/stats.png"}
    },
    navOptions = {defaultSection = "hardware", showProgress = true},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false}
}
