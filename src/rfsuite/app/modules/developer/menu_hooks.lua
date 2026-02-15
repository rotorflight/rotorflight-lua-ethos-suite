--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "Developer",
    loaderSpeed = 0.08,
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    pages = {
        {name = "@i18n(app.modules.msp_speed.name)@", script = "developer/tools/msp_speed.lua", image = "app/modules/developer/gfx/msp_speed.png", bgtask = true, offline = true},
        {name = "@i18n(app.modules.api_tester.name)@", script = "developer/tools/api_tester.lua", image = "app/modules/developer/gfx/api_tester.png", bgtask = true, offline = true},
        {name = "@i18n(app.modules.msp_exp.name)@", script = "developer/tools/msp_exp.lua", image = "app/modules/developer/gfx/msp_exp.png", bgtask = true, offline = true},
        {name = "@i18n(app.modules.settings.name)@", script = "settings/tools/development.lua", image = "app/modules/developer/gfx/settings.png", bgtask = true, offline = true}
    },
    childTitleResolver = function(_, item)
        return "Developer / " .. item.name
    end
}
