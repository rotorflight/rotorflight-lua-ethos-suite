--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local loadfile = loadfile
local table_insert = table.insert
local table_remove = table.remove
local tostring = tostring
local type = type
local pairs = pairs
local ipairs = ipairs
local string_format = string.format

local utils = rfsuite.utils

local api2 = {}

api2._fileExistsCache = {}
api2._chunkCache = {}
api2._chunkCacheOrder = {}
api2._chunkCacheMax = 12
api2._deltaCacheDefault = true
api2._deltaCacheByApi = {}
api2._ported = {}
api2.apidata = {}
api2._core = nil

local defaultApiPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/api/"
local defaultCorePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/core.lua"

local function currentApiEngine()
    local tasks = rfsuite and rfsuite.tasks
    local msp = tasks and tasks.msp
    if msp and msp.getApiEngine then
        return msp.getApiEngine()
    end
    return "v2"
end

local function logApiIo(apiName, op, source)
    if not (utils and utils.log) then return end
    utils.log(
        string_format(
            "[msp] %s %s via engine=%s source=%s",
            tostring(op),
            tostring(apiName),
            tostring(currentApiEngine()),
            tostring(source or "unknown")
        ),
        "info"
    )
end

local function normalizePath(value)
    if type(value) ~= "string" or value == "" then return nil end
    if value:sub(1, 8) == "SCRIPTS:/" then
        return value
    end
    return defaultApiPath .. value
end

local function resolvePath(apiName)
    return normalizePath(api2._ported[apiName]) or (defaultApiPath .. apiName .. ".lua")
end

local function ensureCore()
    if api2._core then return api2._core end

    local coreLoader, err = loadfile(defaultCorePath)
    if not coreLoader then
        utils.log("[apiv2] core compile failed: " .. tostring(err), "info")
        return nil
    end

    local core = coreLoader()
    api2._core = core

    local tasks = rfsuite and rfsuite.tasks
    local msp = tasks and tasks.msp
    if msp then
        msp.apiv2core = core
    end

    return core
end

local function cachedFileExists(path)
    if api2._fileExistsCache[path] == nil then
        api2._fileExistsCache[path] = utils.file_exists(path)
    end
    return api2._fileExistsCache[path]
end

local function getChunk(apiName, path)
    local chunk = api2._chunkCache[apiName]
    if chunk then
        for i, name in ipairs(api2._chunkCacheOrder) do
            if name == apiName then
                table_remove(api2._chunkCacheOrder, i)
                break
            end
        end
        table_insert(api2._chunkCacheOrder, apiName)
        return chunk
    end

    local loaderFn, err = loadfile(path)
    if not loaderFn then
        utils.log("[apiv2] compile failed for " .. tostring(apiName) .. ": " .. tostring(err), "info")
        return nil
    end

    api2._chunkCache[apiName] = loaderFn
    table_insert(api2._chunkCacheOrder, apiName)

    if #api2._chunkCacheOrder > api2._chunkCacheMax then
        local oldest = table_remove(api2._chunkCacheOrder, 1)
        api2._chunkCache[oldest] = nil
    end

    return loaderFn
end

local function validateModule(apiName, module)
    if type(module) ~= "table" then
        return nil, "module_not_table"
    end
    if not module.read and not module.write then
        return nil, "module_missing_read_write"
    end

    module.__apiName = apiName
    module.__apiSource = module.__apiSource or "apiv2"

    if module.read and not module.__rfWrappedRead then
        local original = module.read
        module.read = function(...)
            logApiIo(apiName, "read", module.__apiSource)
            return original(...)
        end
        module.__rfWrappedRead = true
    end

    if module.write and not module.__rfWrappedWrite then
        local original = module.write
        module.write = function(...)
            logApiIo(apiName, "write", module.__apiSource)
            return original(...)
        end
        module.__rfWrappedWrite = true
    end

    return module
end

function api2.enableDeltaCache(enable)
    if enable == nil then return end
    api2._deltaCacheDefault = (enable == true)
end

function api2.setApiDeltaCache(apiName, enable)
    if type(apiName) ~= "string" or apiName == "" then return end
    if enable == nil then
        api2._deltaCacheByApi[apiName] = nil
        return
    end
    api2._deltaCacheByApi[apiName] = (enable == true)
end

function api2.isDeltaCacheEnabled(apiName)
    if apiName and api2._deltaCacheByApi[apiName] ~= nil then
        return api2._deltaCacheByApi[apiName]
    end
    local app = rfsuite and rfsuite.app
    if not (app and app.guiIsRunning) then
        return false
    end
    return api2._deltaCacheDefault == true
end

function api2.register(apiName, modulePath)
    if type(apiName) ~= "string" or apiName == "" then return false end
    if type(modulePath) ~= "string" or modulePath == "" then return false end
    api2._ported[apiName] = modulePath
    api2._chunkCache[apiName] = nil
    return true
end

function api2.unregister(apiName)
    if type(apiName) ~= "string" or apiName == "" then return false end
    api2._ported[apiName] = nil
    api2._chunkCache[apiName] = nil
    return true
end

function api2.isPorted(apiName)
    if type(apiName) ~= "string" or apiName == "" then return false end
    return cachedFileExists(resolvePath(apiName)) == true
end

function api2.load(apiName)
    if type(apiName) ~= "string" or apiName == "" then
        utils.log("[apiv2] invalid api name", "info")
        return nil
    end

    if not ensureCore() then
        utils.log("[apiv2] core unavailable; cannot load " .. tostring(apiName), "info")
        return nil
    end

    local path = resolvePath(apiName)
    if not cachedFileExists(path) then
        utils.log("[apiv2] API file not found: " .. tostring(path), "info")
        return nil
    end

    local chunk = getChunk(apiName, path)
    if not chunk then return nil end

    local apiModule = chunk()
    local module, reason = validateModule(apiName, apiModule)
    if not module then
        utils.log("[apiv2] invalid module for " .. tostring(apiName) .. ": " .. tostring(reason), "info")
        return nil
    end

    module.enableDeltaCache = function(enable) api2.setApiDeltaCache(apiName, enable) end
    module.isDeltaCacheEnabled = function() return api2.isDeltaCacheEnabled(apiName) end

    return module
end

function api2.resetApidata()
    local d = api2.apidata

    if d.values then
        for k in pairs(d.values) do d.values[k] = nil end
    end
    if d.structure then
        for k in pairs(d.structure) do d.structure[k] = nil end
    end
    if d.receivedBytesCount then
        for k in pairs(d.receivedBytesCount) do d.receivedBytesCount[k] = nil end
    end
    if d.receivedBytes then
        for k in pairs(d.receivedBytes) do d.receivedBytes[k] = nil end
    end
    if d.positionmap then
        for k in pairs(d.positionmap) do d.positionmap[k] = nil end
    end
    if d.other then
        for k in pairs(d.other) do d.other[k] = nil end
    end

    api2.apidata = {}
end

function api2.clearChunkCache()
    api2._chunkCache = {}
    api2._chunkCacheOrder = {}
end

function api2.clearFileExistsCache()
    api2._fileExistsCache = {}
end

return api2
