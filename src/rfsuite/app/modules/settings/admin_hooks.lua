--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "@i18n(app.modules.settings.name)@",
    loaderSpeed = 0.08,
    navOptions = {showProgress = true},
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    pages = {
        {name = "@i18n(app.modules.settings.txt_general)@", script = "general.lua", image = "general.png"},
        {name = "@i18n(app.modules.settings.dashboard)@", script = "dashboard.lua", image = "dashboard.png"},
        {name = "@i18n(app.modules.settings.localizations)@", script = "localizations.lua", image = "localizations.png"},
        {name = "@i18n(app.modules.settings.audio)@", script = "audio.lua", image = "audio.png"}
    }
}
