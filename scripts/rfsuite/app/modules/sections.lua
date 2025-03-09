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

sections[#sections + 1] = {title = rfsuite.i18n.get("app.menu_section_flight_tuning")}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.menu_section_advanced")}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.menu_section_hardware")}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.menu_section_tools")}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.menu_section_developer"), developer = true}
sections[#sections + 1] = {title = rfsuite.i18n.get("app.menu_section_about")}

return sections
