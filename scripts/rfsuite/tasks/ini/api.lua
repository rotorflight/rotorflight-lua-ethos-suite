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
 
--[[
    ini/api.lua

    Wrapper for INI-based APIs. Loads per-API modules from files in a configurable folder,
    delegates granular read/write operations to them, and handles file I/O via the generic ini library.

    USAGE:
        -- Load the API for section "TEST_API"
        local api = require("ini.api").load("TEST_API")
        
        -- Point to your INI file
        api.setIniFile("path/to/logs.ini")
        
        -- Read a single field:
        local pitch = api.readValue("pitch")
        
        -- Read all defined fields (with defaults):
        local cfg = api.read()
        -- cfg is a table, e.g. { pitch = 0, roll = 0, ... }
        
        -- Stage changes:
        api.setValue("pitch", 12.34)
        api.setValue("roll",  -5.67)
        
        -- Persist staged changes:
        local ok, err = api.write()
        if not ok then error("Failed to save INI: " .. err) end
--]]


local ini      = rfsuite.ini
local apidir   = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/ini/api/"
local compiler = rfsuite.compiler

local M = {}

---
-- Create a new API instance for a given section/module name.
-- Provides methods: readValue, setValue, read, write.
-- @param apiName string  Name of the API (and INI section) to load
-- @return table          Instance
function M.load(apiName)
    assert(type(apiName) == "string", "apiName must be a string")

    -- Build full path to the API definition file
    local apiFile = apidir .. apiName .. ".lua"
    -- Load the API definition module via dofile
    local ok, apiDef = pcall(function()
        return compiler.dofile(apiFile)
    end)
    assert(ok and type(apiDef) == "table", "Failed to load API module: " .. apiFile)

    local instance = {}
    local iniPath  = nil
    local data     = nil      -- cached INI data
    local staged   = {}       -- pending writes

    --- Set the path to the INI file this instance will operate on.
    -- @param path string
    function instance.setIniFile(path)
        assert(type(path) == "string", "Path must be a string")
        iniPath = path
        data    = nil
        staged  = {}
    end

    -- Ensure data is loaded from disk
    local function ensureLoaded()
        assert(iniPath, "INI file not set. Call setIniFile(path) first.")
        if not data then
            local loaded, err = ini.load_ini_file(iniPath)
            if not loaded then
                error("Failed to load INI file: " .. tostring(err))
            end
            data = loaded
        end
    end

    --- Read a single field value from the section (no defaults applied)
    -- @param field string
    -- @return any
    function instance.readValue(field)
        ensureLoaded()
        if apiDef.readValue then
            return apiDef.readValue(data, apiName, field)
        end
        local section = data[apiName] or {}
        return section[field]
    end

    --- Read all defined fields, applying defaults if provided
    -- @return table  key->value map
    function instance.read()
        ensureLoaded()
        if apiDef.readComplete then
            return apiDef.readComplete(data, apiName)
        end
        local out = {}
        local sec = data[apiName] or {}
        for _, def in ipairs(apiDef.API_STRUCTURE or {}) do
            local key = type(def) == "table" and def.field or def
            out[key] = sec[key]
            if out[key] == nil and type(def) == "table" and def.default ~= nil then
                out[key] = def.default
            end
        end
        return out
    end

    --- Stage a single field to be written later (does NOT save to disk until write is called)
    -- @param field string, @param value any
    function instance.setValue(field, value)
        staged[field] = value
    end

    --- Commit all staged writes to disk
    -- @return boolean, string?  true on success, or false+error message
    function instance.write()
        ensureLoaded()
        for k, v in pairs(staged) do
            ini.setvalue(data, apiName, k, v)
        end
        local ok, err = ini.save_ini_file(iniPath, data)
        if not ok then
            return false, err
        end
        staged = {}
        return true
    end

    return instance
end

return M
