--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local ini = {}

function ini.load_file_as_string(path)
    local f = io.open(path, "rb")
    if not f then return nil, "Cannot open file: " .. path end

    local content = ""
    local chunk
    repeat
        chunk = io.read(f, "L")
        if chunk then content = content .. chunk end
    until not chunk

    io.close(f)
    return content
end

function ini.load_ini_file(fileName)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.')

    local content, err = ini.load_file_as_string(fileName)
    if not content then return nil end

    local data = {}
    local section = nil

    for line in string.gmatch(content, "[^\r\n]+") do
        line = line:match("^%s*(.-)%s*$")

        if line == "" or line:sub(1, 1) == ";" then

        elseif line:match("^%[.+%]$") then
            section = line:match("^%[(.+)%]$")
            if section then
                section = section:match("^%s*(.-)%s*$")
                section = tonumber(section) or section
                data[section] = data[section] or {}
            end
        else
            local param, value = line:match("^([%w_]+)%s-=%s-(.*)$")
            if param and value then
                param = tonumber(param) or param

                if value == "true" then
                    value = true
                elseif value == "false" then
                    value = false
                elseif tonumber(value) then
                    value = tonumber(value)
                end

                if section then data[section][param] = value end
            end
        end
    end

    return data
end

function ini.save_ini_file(fileName, data)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.')
    assert(type(data) == 'table', 'Parameter "data" must be a table.')

    local file, err = io.open(fileName, 'w')
    if not file then return false end

    for section, params in pairs(data) do
        file:write(("[" .. tostring(section) .. "]\n"))
        for key, value in pairs(params) do
            if type(value) == "boolean" then value = value and "true" or "false" end
            file:write(("%s=%s\n"):format(tostring(key), tostring(value)))
        end
        file:write("\n")
    end

    file:close()
    return true
end

function ini.merge_ini_tables(master, slave)
    assert(type(master) == "table", "master must be a table")
    assert(type(slave) == "table", "slave must be a table")

    local merged = {}

    for section, slaveSection in pairs(slave) do
        merged[section] = {}

        for key, value in pairs(slaveSection) do merged[section][key] = value end

        if master[section] then for key, value in pairs(master[section]) do merged[section][key] = value end end
    end

    for section, masterSection in pairs(master) do
        if not merged[section] then
            merged[section] = {}
            for key, value in pairs(masterSection) do merged[section][key] = value end
        end
    end

    return merged
end

function ini.ini_tables_equal(a, b)
    for section, b_vals in pairs(b) do
        local a_vals = a[section] or {}
        for k, v in pairs(b_vals) do if a_vals[k] == nil then return false end end
    end
    return true
end

function ini.getvalue(data, section, key)
    if data and section and key then if data[section] and data[section][key] ~= nil then return data[section][key] end end
    return nil
end

function ini.section_exists(data, section) return data and data[section] ~= nil end

function ini.setvalue(data, section, key, value)
    if not data then return end
    if not data[section] then data[section] = {} end
    data[section][key] = value
end

return ini
