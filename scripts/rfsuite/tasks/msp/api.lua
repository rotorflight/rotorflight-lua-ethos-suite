--
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

-- Define the API directory path based on the ethos version
local apidir = "tasks/msp/api/"
local api_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and apidir or (config.suiteDir .. apidir)

local api = {}

-- Store loaded modules to avoid reloading
api.modules = {}

function api.use(moduleName)
    if not api.modules[moduleName] then
        local path = api_path .. moduleName .. ".lua"

        local mod = assert(loadfile(path))()
        api.modules[moduleName] = mod
        mod:init()


    end
    return api.modules[moduleName]
end

return api