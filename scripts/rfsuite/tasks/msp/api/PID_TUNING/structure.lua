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

-- Function to generate the PID structure
local function generate_pid_structure(pid_axis_count, cyclic_axis_count)
    local structure = {}

    for i = 0, pid_axis_count - 1 do
        table.insert(structure, { field = "pid_" .. i .. "_P", type = "U16" })
        table.insert(structure, { field = "pid_" .. i .. "_I", type = "U16" })
        table.insert(structure, { field = "pid_" .. i .. "_D", type = "U16" })
        table.insert(structure, { field = "pid_" .. i .. "_F", type = "U16" })
    end

    for i = 0, pid_axis_count - 1 do
        table.insert(structure, { field = "pid_" .. i .. "_B", type = "U16" })
    end

    for i = 0, cyclic_axis_count - 1 do
        table.insert(structure, { field = "pid_" .. i .. "_O", type = "U16" })
    end

    return structure
end

-- Export the shared MSP API structure
return {
    generate_pid_structure = generate_pid_structure,
    MSP_API_STRUCTURE = generate_pid_structure(3, 2) -- Adjust values as needed
}