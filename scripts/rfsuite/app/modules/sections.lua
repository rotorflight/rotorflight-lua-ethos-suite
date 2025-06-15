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
local i18n = rfsuite.i18n.get

sections[#sections + 1] = {title = i18n("app.menu_section_flight_tuning"), id = "flight_tuning"}
sections[#sections + 1] = {title = i18n("app.menu_section_advanced"), id = "advanced"}
sections[#sections + 1] = {title = i18n("app.menu_section_hardware"), id = "hardware"}
sections[#sections + 1] = {title = i18n("app.menu_section_tools"), id = "tools"}
sections[#sections + 1] = {title = i18n("app.menu_section_developer"), id = "developer", developer = true}
sections[#sections + 1] = {title = i18n("app.menu_section_about"), id = "about"}

return sections
