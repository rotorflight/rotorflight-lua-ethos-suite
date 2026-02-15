--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "@i18n(app.modules.hardware_setup.name)@",
    pages = {
        {name = "@i18n(app.modules.configuration.name)@", script = "configuration/configuration.lua", image = "app/modules/configuration/configuration.png"},
        {name = "@i18n(app.modules.servos.name)@", script = "servos/servos.lua", image = "app/modules/servos/servos.png"},
        {name = "@i18n(app.modules.mixer.name)@", script = "mixer/mixer.lua", image = "app/modules/mixer/mixer.png"},
        {name = "@i18n(app.modules.esc_motors.name)@", script = "esc_motors/esc_motors.lua", image = "app/modules/esc_motors/esc.png"},
        {name = "@i18n(app.modules.accelerometer.name)@", script = "accelerometer/accelerometer.lua", image = "app/modules/accelerometer/acc.png"},
        {name = "@i18n(app.modules.alignment.name)@", script = "alignment/alignment.lua", image = "app/modules/alignment/alignment.png"}
    },
    loaderSpeed = 0.08,
    navOptions = {defaultSection = "hardware", showProgress = true},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false}
}
