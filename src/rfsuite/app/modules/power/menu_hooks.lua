--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "@i18n(app.modules.power.name)@",
    scriptPrefix = "power/tools/",
    iconPrefix = "app/modules/power/gfx/",
    loaderSpeed = 0.08,
    navOptions = {defaultSection = "hardware"},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    pages = {
        {name = "@i18n(app.modules.power.battery_name)@", script = "battery.lua", image = "battery.png"},
        {name = "@i18n(app.modules.power.alert_name)@", script = "alerts.lua", image = "alerts.png"},
        {name = "@i18n(app.modules.power.source_name)@", script = "source.lua", image = "source.png"}
    }
}
