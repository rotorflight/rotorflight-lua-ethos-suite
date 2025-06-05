--[[
 * Copyright (C) Rotorflight Project
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
]] --
local object = {}

-- This function is called by toolbox.lua
-- it should return a string that will be used as the
-- value for the displayed object.  all rendering is handled
-- by toolbox.lua.  It is called once when lcd.invalidate() is called
function object.render(widget)
    return "0%"
end

-- This function is called in a loop by toolbox.lua
-- it should process anything that is needed for determining
-- what object.render does.  
function object.wakeup(widget)
    
end



return object
