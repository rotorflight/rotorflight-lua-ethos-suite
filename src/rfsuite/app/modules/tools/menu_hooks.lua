--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

return {
    title = "@i18n(app.menu_section_tools)@",
    pages = {
        {name = "@i18n(app.modules.copyprofiles.name)@", script = "copyprofiles/copyprofiles.lua", image = "copyprofiles/copy.png", order = 1, apiversion = "12.06", disabled = true},
        {name = "@i18n(app.modules.profile_select.name)@", script = "profile_select/select_profile.lua", image = "profile_select/select_profile.png", order = 2, apiversion = "12.06"}
    }
}

