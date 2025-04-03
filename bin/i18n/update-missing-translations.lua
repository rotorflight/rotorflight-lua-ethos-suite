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

 * This script scans the en.json files and then updates all other
 * language files to ensure we have no missing keys.
 * 
 * the updated file will be written back to the original location.
 * the translation will be set to "MISSING TRANSLATION" for any missing keys. 

]]

local json = dofile("lib/dkjson.lua")

local jsonRoot = "json"
local isWindows = package.config:sub(1,1) == "\\"

-- Helper: list files/dirs in a folder
local function listDir(path)
    local cmd = isWindows
        and ('dir /b "%s" 2>nul'):format(path)
        or ('ls -1 "%s" 2>/dev/null'):format(path)
    local pipe = io.popen(cmd)
    local result = {}
    for line in pipe:lines() do
        table.insert(result, line)
    end
    pipe:close()
    return result
end

-- Helper: check if a path is a directory
local function isDir(path)
    local cmd = isWindows
        and ('if exist "%s\\" (echo d)'):format(path)
        or ('[ -d "%s" ] && echo d'):format(path)
    local pipe = io.popen(cmd)
    local result = pipe:read("*a")
    pipe:close()
    return result:match("d")
end

-- Recursively collect directories under a given path
local function collectDirs(path, rel, dirs)
    rel = rel or ""
    dirs = dirs or {}
    local fullPath = path .. (rel ~= "" and "/" .. rel or "")
    for _, entry in ipairs(listDir(fullPath)) do
        local entryRel = rel ~= "" and (rel .. "/" .. entry) or entry
        local entryFull = fullPath .. "/" .. entry
        if isDir(entryFull) then
            table.insert(dirs, entryFull)
            collectDirs(path, entryRel, dirs)
        end
    end
    return dirs
end

-- Merge defaults from the reference table (ref) into target.
-- For leaf nodes (objects with "english" and "translation" keys),
-- if missing in target, insert with the english text and "MISSING TRANSLATION" as the translation.
local function mergeDefaults(ref, target)
    for k, v in pairs(ref) do
        if type(v) == "table" and v.english ~= nil and v.translation ~= nil then
            if target[k] == nil then
                target[k] = { english = v.english, translation = "MISSING TRANSLATION" }
            end
        elseif type(v) == "table" then
            if type(target[k]) ~= "table" then
                target[k] = {}
            end
            mergeDefaults(v, target[k])
        else
            if target[k] == nil then
                target[k] = v
            end
        end
    end
end

-- Process a single directory: if an en.json exists, update all other *.json files in that directory.
local function processDirectory(dirPath)
    local files = listDir(dirPath)
    local enFilePath = nil
    for _, filename in ipairs(files) do
        if filename == "en.json" then
            enFilePath = dirPath .. "/" .. filename
            break
        end
    end

    if not enFilePath then
        -- Nothing to do if there's no English reference file.
        return
    end

    -- Load the reference English JSON file.
    local f = io.open(enFilePath, "r")
    if not f then return end
    local enContent = f:read("*a")
    f:close()
    local enData = json.decode(enContent)
    if not enData then
        print("⚠️ Failed to decode", enFilePath)
        return
    end

    -- Update each non-English JSON file in this directory.
    for _, filename in ipairs(files) do
        if filename:match("^(%w+)%.json$") and filename ~= "en.json" then
            local filePath = dirPath .. "/" .. filename
            local f2 = io.open(filePath, "r")
            if f2 then
                local content = f2:read("*a")
                f2:close()
                local data = json.decode(content) or {}
                mergeDefaults(enData, data)
                -- Write back the updated JSON.
                local outFile = io.open(filePath, "w")
                if outFile then
                    outFile:write(json.encode(data, { indent = true }))
                    outFile:close()
                    print("Updated:", filePath)
                else
                    print("⚠️ Could not open for writing:", filePath)
                end
            end
        end
    end
end

-- Main: recursively process every directory in the JSON tree
local function updateMissingTranslations()
    -- Process the root directory as well.
    processDirectory(jsonRoot)
    local dirs = collectDirs(jsonRoot)
    for _, dir in ipairs(dirs) do
        processDirectory(dir)
    end
end

updateMissingTranslations()
