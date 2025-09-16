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
local init = {
    title = "@i18n(app.modules.filters.name)@", -- title of the page
    section = "hardware", -- do not run if busy with msp
    script = "filters.lua", -- run this script
    image = "filters.png", -- image for the page
    order = 9, -- order in the section
    ethosversion = {1, 6, 2} -- disable button if ethos version is less than this
}

return init
