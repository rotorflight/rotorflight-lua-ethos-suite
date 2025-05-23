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
]]

local function normalize_path(path)
    return path:gsub("\\", "/"):gsub("//", "/")
end

local function list_lua_files(folder)
    local isWindows = package.config:sub(1, 1) == "\\"
    local cmd = isWindows
        and ('dir /b "%s" 2>nul'):format(folder)
        or ('ls -1 "%s" 2>/dev/null'):format(folder)

    local p = io.popen(cmd)
    local files = {}
    for line in p:lines() do
        if line:match("%.lua$") and line ~= "en.lua" then
            table.insert(files, line)
        end
    end
    p:close()
    return files
end

local function load_table(filepath)
    local chunk, err = loadfile(filepath)
    if not chunk then return nil, err end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then return nil, "Invalid return" end
    return result
end

local function flatten(tbl, prefix, flat)
    flat = flat or {}
    prefix = prefix or ""
    for k, v in pairs(tbl) do
        local path = prefix ~= "" and (prefix .. "." .. k) or k
        if type(v) == "table" then
            flatten(v, path, flat)
        else
            flat[path] = true
        end
    end
    return flat
end

local function check_missing_keys(en_table, other_table, lang_name)
    local missing = {}
    local en_flat = flatten(en_table)
    local other_flat = flatten(other_table)

    for key in pairs(en_flat) do
        if not other_flat[key] then
            table.insert(missing, key)
        end
    end

    if #missing > 0 then
        print("\nMissing keys in " .. lang_name .. ":")
        for _, key in ipairs(missing) do
            print("  - " .. key)
        end
    else
        print("\n" .. lang_name .. " has all keys.")
    end
end

-- Determine root directory from command-line or default
local root_folder = arg[1]
if not root_folder or root_folder == "" then
    print("[INFO] No root folder provided. Using default: ../../scripts/rfsuite/i18n/")
    root_folder = "../../scripts/rfsuite/i18n/"
end

root_folder = normalize_path(root_folder)
print("Checking translations in folder:", root_folder)

local en, err = load_table(root_folder .. "/en.lua")
if not en then
    print("Failed to load en.lua:", err)
    os.exit(1)
end

for _, file in ipairs(list_lua_files(root_folder)) do
    local lang = file:gsub("%.lua$", "")
    local path = root_folder .. "/" .. file
    local tbl, err = load_table(path)
    if tbl then
        check_missing_keys(en, tbl, lang)
    else
        print("Failed to load " .. file .. ": " .. tostring(err))
    end
end
