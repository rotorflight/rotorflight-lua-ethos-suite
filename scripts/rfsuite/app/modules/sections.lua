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
local i18n = rfsuite.i18n.get

-- main menu sections

sections[#sections + 1] = {title = rfsuite.i18n.get("app.modules.pids.name"), module = "pids", script = "pids.lua", image = "app/modules/pids/pids.png"}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.modules.rates.name"), module = "rates", script = "rates.lua", image = "app/modules/rates/rates.png"}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.modules.profile_governor.name"), module = "profile_governor", script = "profile_governor.lua", image = "app/modules/profile_governor/governor.png"}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.modules.profile_tailrotor.name"), module = "tailrotor", script = "tailrotor.lua", image = "app/modules/tailrotor/tailrotor.png"}
sections[#sections + 1] = {title = i18n("app.menu_section_advanced"), id = "advanced", image = "app/gfx/advanced.png", loaderspeed = true}
sections[#sections + 1] = {title = i18n("app.menu_section_hardware"), id = "hardware", image = "app/gfx/hardware.png", loaderspeed = true}
sections[#sections + 1] = {title = i18n("app.menu_section_tools"), id = "tools", image = "app/gfx/tools.png", newline = true}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.modules.logs.name"), offline = true, module = "logs", script = "logs_dir.lua", image = "app/modules/logs/gfx/logs.png", loaderspeed = true}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.modules.settings.name"), offline = true,  module = "settings", script = "settings.lua", image = "app/modules/settings/settings.png", loaderspeed = true}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.modules.about.name"),  module = "about", script = "about.lua", image = "app/modules/about/about.png", loaderspeed = true}

return sections
