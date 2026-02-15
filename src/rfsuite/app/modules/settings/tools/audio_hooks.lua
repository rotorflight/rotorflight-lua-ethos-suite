--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

return {
    title = "@i18n(app.modules.settings.name)@ / @i18n(app.modules.settings.audio)@",
    moduleKey = "settings_dashboard_audio",
    scriptPrefix = "settings/tools/",
    iconPrefix = "app/modules/settings/gfx/",
    navButtons = {menu = true, save = false, reload = false, tool = false, help = false},
    pages = {
        {name = "@i18n(app.modules.settings.txt_audio_events)@", script = "audio_events.lua", image = "audio_events.png"},
        {name = "@i18n(app.modules.settings.txt_audio_switches)@", script = "audio_switches.lua", image = "audio_switches.png"},
        {name = "@i18n(app.modules.settings.txt_audio_timer)@", script = "audio_timer.lua", image = "audio_timer.png"}
    },
    navOptions = {showProgress = true}
}
