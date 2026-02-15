--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "@i18n(app.menu_section_advanced)@",
    loaderSpeed = "FAST",
    pages = {
        {name = "@i18n(app.modules.profile_pidcontroller.name)@", script = "profile_pidcontroller/pidcontroller.lua", image = "profile_pidcontroller/pids-controller.png", order = 1, apiversion = "12.06"},
        {name = "@i18n(app.modules.profile_pidbandwidth.name)@", script = "profile_pidbandwidth/pidbandwidth.lua", image = "profile_pidbandwidth/pids-bandwidth.png", order = 2, apiversion = "12.06"},
        {name = "@i18n(app.modules.profile_autolevel.name)@", script = "profile_autolevel/autolevel.lua", image = "profile_autolevel/autolevel.png", order = 3, apiversion = "12.06"},
        {name = "@i18n(app.modules.profile_mainrotor.name)@", script = "profile_mainrotor/mainrotor.lua", image = "profile_mainrotor/mainrotor.png", order = 4, apiversion = "12.06"},
        {name = "@i18n(app.modules.profile_tailrotor.name)@", script = "profile_tailrotor/tailrotor.lua", image = "profile_tailrotor/tailrotor.png", order = 5, apiversion = "12.06"},
        {name = "@i18n(app.modules.profile_rescue.name)@", script = "profile_rescue/rescue.lua", image = "profile_rescue/rescue.png", order = 6, apiversion = "12.06"},
        {name = "@i18n(app.modules.rates_advanced.name)@", script = "rates_advanced/rates_advanced.lua", image = "rates_advanced/rates.png", order = 7, apiversion = "12.06"}
    }
}

