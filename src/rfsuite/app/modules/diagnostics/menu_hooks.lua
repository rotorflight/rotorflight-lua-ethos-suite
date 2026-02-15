--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "@i18n(app.modules.diagnostics.name)@",
    scriptPrefix = "diagnostics/tools/",
    iconPrefix = "app/modules/diagnostics/gfx/",
    loaderSpeed = 0.08,
    navOptions = {},
    pages = {
        {name = "@i18n(app.modules.rfstatus.name)@", script = "rfstatus.lua", image = "rfstatus.png", bgtask = false, offline = false},
        {name = "@i18n(app.modules.validate_sensors.name)@", script = "sensors.lua", image = "sensors.png", bgtask = true, offline = true},
        {name = "FBL Sensors", script = "fblsensors.lua", image = "fblsensors.png", bgtask = true, offline = true},
        {name = "@i18n(app.modules.fblstatus.name)@", script = "fblstatus.lua", image = "fblstatus.png", bgtask = true, offline = true},
        {name = "@i18n(app.modules.info.name)@", script = "info.lua", image = "info.png", bgtask = true, offline = true}
    }
}
