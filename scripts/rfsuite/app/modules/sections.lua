--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local sections = {}
local tools = {}


-- main menu sections

sections[#sections + 1] = {
    title = "@i18n(app.modules.pids.name)@",
    module = "pids",
    script = "pids.lua",
    image = "app/modules/pids/pids.png",
    offline = false,
    bgtask = false,     
}
sections[#sections + 1] = {
    title = "@i18n(app.modules.rates.name)@",
    module = "rates",
    script = "rates.lua",
    image = "app/modules/rates/rates.png",
    offline = false,
    bgtask = false,     
}
sections[#sections + 1] = {
    title = "@i18n(app.modules.profile_governor.name)@",
    module = "profile_governor",
    script = "select.lua",
    image = "app/modules/profile_governor/governor.png",
    offline = false,
    bgtask = false,     
}
sections[#sections + 1] = {
    title = "@i18n(app.modules.profile_tailrotor.name)@",
    module = "tailrotor",
    script = "tailrotor.lua",
    image = "app/modules/tailrotor/tailrotor.png",
    offline = false,
    bgtask = false,     
}
sections[#sections + 1] = {
    title = "@i18n(app.menu_section_advanced)@",
    id = "advanced",
    image = "app/gfx/advanced.png",
    loaderspeed = true,
    offline = false,
    bgtask = false,     
}
sections[#sections + 1] = {
    title = "@i18n(app.menu_section_hardware)@",
    id = "hardware",
    image = "app/gfx/hardware.png",
    loaderspeed = true,
    offline = false,
    bgtask = false,     
}
sections[#sections + 1] = {
    title = "@i18n(app.menu_section_tools)@",
    id = "tools",
    image = "app/gfx/tools.png",
    newline = true,
    offline = false,
    bgtask = false,    
}
sections[#sections + 1] = {
    title = "@i18n(app.modules.logs.name)@",
    module = "logs",
    script = "logs_dir.lua",
    image = "app/modules/logs/gfx/logs.png",
    loaderspeed = true,
    offline = true,
    bgtask = false,
}
sections[#sections + 1] = {
    title = "@i18n(app.modules.settings.name)@",
    module = "settings",
    script = "settings.lua",
    image = "app/modules/settings/settings.png",
    loaderspeed = true,
    offline = true,
    bgtask = false,
}
sections[#sections + 1] = {
    title = "@i18n(app.modules.diagnostics.name)@",
    module = "diagnostics",
    script = "diagnostics.lua",
    image = "app/modules/diagnostics/diagnostics.png",
    loaderspeed = true,
    bgtask = true,
    offline = true,
}


return sections
