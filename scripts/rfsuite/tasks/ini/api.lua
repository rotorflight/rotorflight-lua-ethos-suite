--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local ini = rfsuite.ini
local apidir = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/ini/api/"

local M = {}

function M.load(apiName)
    assert(type(apiName) == "string", "apiName must be a string")

    local apiFile = apidir .. apiName .. ".lua"

    local ok, apiDef = pcall(function() return compiler.dofile(apiFile) end)
    assert(ok and type(apiDef) == "table", "Failed to load API module: " .. apiFile)

    local instance = {}
    local iniPath = nil
    local data = nil
    local staged = {}

    function instance.setIniFile(path)
        assert(type(path) == "string", "Path must be a string")
        iniPath = path
        data = nil
        staged = {}
    end

    local function ensureLoaded()
        assert(iniPath, "INI file not set. Call setIniFile(path) first.")
        if not data then
            local loaded, err = ini.load_ini_file(iniPath)
            if not loaded then error("Failed to load INI file: " .. tostring(err)) end
            data = loaded
        end
    end

    function instance.readValue(field)
        ensureLoaded()
        if apiDef.readValue then return apiDef.readValue(data, apiName, field) end
        local section = data[apiName] or {}
        return section[field]
    end

    function instance.read()
        ensureLoaded()
        if apiDef.readComplete then return apiDef.readComplete(data, apiName) end
        local out = {}
        local sec = data[apiName] or {}
        for _, def in ipairs(apiDef.API_STRUCTURE or {}) do
            local key = type(def) == "table" and def.field or def
            out[key] = sec[key]
            if out[key] == nil and type(def) == "table" and def.default ~= nil then out[key] = def.default end
        end
        return out
    end

    function instance.setValue(field, value) staged[field] = value end

    function instance.write()
        ensureLoaded()
        for k, v in pairs(staged) do ini.setvalue(data, apiName, k, v) end
        local ok, err = ini.save_ini_file(iniPath, data)
        if not ok then return false, err end
        staged = {}
        return true
    end

    return instance
end

return M
