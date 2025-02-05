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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * Note. Some icons have been sourced from https://www.flaticon.com/
]] --

-- Define the MSP response data structure
local function readStructure(count)
    local structure = {}
    for i = 1, count do
        table.insert(structure,
                     {field = string.format("servo%d", i), type = "U16"})
    end
    return structure
end

MSP_API_STRUCTURE_WRITE = {
    { field = "servo_id", type = "U8" },
    { field = "action", type = "U16" },
}


-- Export the shared MSP API structure
return {
    MSP_API_STRUCTURE_READ = readStructure,
    MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_WRITE   
}