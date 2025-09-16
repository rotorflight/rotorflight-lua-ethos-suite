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
    title = "@i18n(app.modules.msp_exp.name)@", -- title of the page
    section = "tools", -- do not run if busy with msp
    script = "msp_exp.lua", -- run this script
    image = "msp_exp.png", -- image for the page
    order = 100, -- order in the section
    developer = true, -- show if developer mode enabled
    ethosversion = {1, 6, 2}, -- disable button if ethos version is less than this
    disable = true
}

return init
