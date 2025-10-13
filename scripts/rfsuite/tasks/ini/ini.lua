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
local rfsuite = require("rfsuite")

--
-- background processing of ini traffic
--
local arg = {...}
local config = arg[1]

local ini = {}


ini.api = assert(loadfile("tasks/ini/api.lua"))()

function ini.wakeup()
    -- currently no processing required
    -- will never fire as interval is set to -1
end

function ini.reset()
    -- currently no reset required
end

return ini
