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

]] --

local LIP = {}

--[[
    LIP.load(fileName)

    Loads and parses an INI file.

    Parameters:
    - fileName (string): The path to the INI file to be loaded.

    Returns:
    - table: A table containing the parsed data from the INI file, or nil if the file could not be loaded.

    The function reads the specified INI file and parses its contents into a Lua table. 
    Each section in the INI file becomes a key in the table, and the key-value pairs within 
    each section are stored as sub-keys and values within the corresponding section table.

    The function handles the following:
    - Trims whitespace from lines.
    - Skips empty lines and comments (lines starting with ';').
    - Parses section headers (lines enclosed in square brackets).
    - Parses key-value pairs (lines in the form of "key = value").
    - Converts values to appropriate types (boolean, number, or string).

    If the file cannot be found or opened, the function logs an error message and returns nil.
    If a key-value pair is found outside of any section, a warning is logged.
]]
function LIP.load(fileName)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.')

    if not rfsuite.utils.file_exists(fileName) then
        rfsuite.utils.log("LIP: Unable to find file: " .. fileName)
        return nil
    end

    local file, err = io.open(fileName, 'r')
    if not file then
        rfsuite.utils.log("LIP: Failed to open file: " .. err)
        return nil
    end

    local data = {}
    local section = nil

    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$")  -- Trim whitespace

        if line == "" or line:sub(1, 1) == ";" then
            -- Skip empty lines or comments
        elseif line:match("^%[.+%]$") then
            section = line:match("^%[(.+)%]$")
            section = tonumber(section) or section
            data[section] = data[section] or {}
        else
            local param, value = line:match("^([%w_]+)%s-=%s-(.*)$")
            if param and value then
                param = tonumber(param) or param

                -- Type conversion for values
                if value == "true" then
                    value = true
                elseif value == "false" then
                    value = false
                elseif tonumber(value) then
                    value = tonumber(value)
                end

                if section then
                    data[section][param] = value
                else
                    rfsuite.utils.log("LIP: Warning - Key-value pair found outside section in " .. fileName)
                end
            end
        end
    end

    file:close()
    return data
end


--[[
    Saves the given data to a file in INI format.

    @param fileName (string) The name of the file to save the data to.
    @param data (table) The data to save, structured as a table where each key is a section name and each value is a table of key-value pairs.

    @return (boolean) True if the file was successfully saved, false otherwise.
]]
function LIP.save(fileName, data)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.')
    assert(type(data) == 'table', 'Parameter "data" must be a table.')

    local file, err = io.open(fileName, 'w')
    if not file then
        rfsuite.utils.log("LIP: Failed to open file for writing: " .. err)
        return false
    end

    for section, params in pairs(data) do
        file:write(("[ %s ]\n"):format(section))
        for key, value in pairs(params) do
            if type(value) == "boolean" then
                value = value and "true" or "false"
            end
            file:write(("%s=%s\n"):format(key, tostring(value)))
        end
        file:write("\n")
    end

    file:close()
    rfsuite.utils.log("LIP: Saved preferences to: " .. fileName)
    return true
end

return LIP