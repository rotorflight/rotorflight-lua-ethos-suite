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

local json = dofile("lib/dkjson.lua")

local jsonRoot = "json"
local outRoot = "../../scripts/rfsuite/i18n"
local isWindows = package.config:sub(1,1) == "\\"

local function readHeader(path)
    local f = io.open(path, "r")
    if not f then return "" end
    local content = f:read("*a")
    f:close()
    return content .. "\n\n"
end

local fileHeader = readHeader("lib/header.txt")

-- Helper: list files/dirs
local function listDir(path)
    local cmd = isWindows
        and ('dir /b "%s" 2>nul'):format(path)
        or ('ls -1 "%s" 2>/dev/null'):format(path)
    local pipe = io.popen(cmd)
    local result = {}
    for line in pipe:lines() do table.insert(result, line) end
    pipe:close()
    return result
end

-- Helper: is directory?
local function isDir(path)
    local cmd = isWindows
        and ('if exist "%s\\" (echo d)'):format(path)
        or ('[ -d "%s" ] && echo d'):format(path)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    pipe:close()
    return result:match("d")
end

-- Ensure output dir exists
local function ensureDir(path)
    local cmd = isWindows
        and ('mkdir "%s" >nul 2>nul'):format(path)
        or ('mkdir -p "%s" 2>/dev/null'):format(path)
    os.execute(cmd)
end

-- Unflatten keys ("a.b.c" => nested table)
local function unflatten(flat)
    local nested = {}
    for key, value in pairs(flat) do
        local current = nested
        for part in string.gmatch(key, "[^%.]+") do
            if not current[part] then current[part] = {} end
            if part == key:match("[^%.]+$") then
                current[part] = value
            else
                current = current[part]
            end
        end
    end
    return nested
end

-- Merge nested tables (recursive)
local function deepMerge(base, new)
    for k, v in pairs(new) do
        if type(v) == "table" and type(base[k]) == "table" then
            deepMerge(base[k], v)
        else
            base[k] = v
        end
    end
end

-- Set nested value by path array
local function insertAtPath(root, pathParts, value)
    if #pathParts == 0 then
        deepMerge(root, value)
        return
    end

    local current = root
    for i = 1, #pathParts - 1 do
        local part = pathParts[i]
        current[part] = current[part] or {}
        current = current[part]
    end

    local lastKey = pathParts[#pathParts]
    current[lastKey] = current[lastKey] or {}
    deepMerge(current[lastKey], value)
end

-- Serialize Lua table to string
local function serializeLuaTable(tbl, indent)
    indent = indent or ""
    local nextIndent = indent .. "  "
    local parts = {"{\n"}
    for k, v in pairs(tbl) do
        local key = string.format("[%q]", k)
        if type(v) == "table" then
            table.insert(parts, string.format("%s%s = %s,\n", nextIndent, key, serializeLuaTable(v, nextIndent)))
        else
            table.insert(parts, string.format("%s%s = %q,\n", nextIndent, key, v))
        end
    end
    table.insert(parts, indent .. "}")
    return table.concat(parts)
end

-- Recursively collect JSON files
local function collectFiles(path, rel, files)
    rel = rel or ""
    files = files or {}
    local fullPath = path .. (rel ~= "" and "/" .. rel or "")
    for _, entry in ipairs(listDir(fullPath)) do
        local subRel = rel ~= "" and (rel .. "/" .. entry) or entry
        local subFull = fullPath .. "/" .. entry
        if isDir(subFull) then
            collectFiles(path, subRel, files)
        elseif entry:match("^(%w+)%.json$") then
            table.insert(files, {
                lang = entry:match("^(%w+)"),
                path = path .. "/" .. subRel,
                relPath = subRel:match("(.+)/%w+%.json$") or ""
            })
        end
    end
    return files
end

-- Process JSON files: use translation for others, only en.json for English
local function buildLanguageTables()
    local allFiles = collectFiles(jsonRoot)
    local translations = {} -- lang -> table

    for _, file in ipairs(allFiles) do
        local lang = file.lang
        local relPathParts = {}
        for part in string.gmatch(file.relPath, "[^/]+") do
            table.insert(relPathParts, part)
        end

        local f = io.open(file.path, "r")
        local content = f:read("*a")
        f:close()

        local parsed = json.decode(content)
        local flat = {}

        for k, v in pairs(parsed) do
            if lang == "en" then
                flat[k] = v.default or v.label or v.translation or v.english or ""
            else
                flat[k] = v.translation or ""
            end
        end

        local nested = unflatten(flat)
        translations[lang] = translations[lang] or {}
        insertAtPath(translations[lang], relPathParts, nested)
    end

    return translations
end

-- Main
local function writeAll()
    local translations = buildLanguageTables()
    ensureDir(outRoot)

    for lang, data in pairs(translations) do
        local outPath = outRoot .. "/" .. lang .. ".lua"
        local f = io.open(outPath, "w")
        f:write(fileHeader)
        f:write("return ")
        f:write(serializeLuaTable(data))
        f:close()
        print("Wrote:", outPath)
    end
end

writeAll()
