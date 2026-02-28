--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
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

local api = {}

api._fileExistsCache = {}
api._chunkCache = {}
api._chunkCacheOrder = {}
api._chunkCacheMax = 5
api._helpChunkCache = {}
api._helpChunkCacheOrder = {}
api._helpChunkCacheMax = 5
api._helpDataCache = {}
api._deltaCacheDefault = true
api._deltaCacheByApi = {}
api._ported = {}
api.apidata = {}
api._core = nil

local defaultApiPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/"
local defaultApiHelpPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apihelp/"
local defaultCorePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"

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
    return normalizePath(api._ported[apiName]) or (defaultApiPath .. apiName .. ".lua")
end

local function resolveHelpPath(apiName)
    if type(apiName) ~= "string" or apiName == "" then return nil end
    return defaultApiHelpPath .. apiName .. ".lua"
end

local function ensureCore()
    if api._core then return api._core end

    local coreLoader, err = loadfile(defaultCorePath)
    if not coreLoader then
        utils.log("[api] core compile failed: " .. tostring(err), "info")
        return nil
    end

    local core = coreLoader()
    api._core = core

    local tasks = rfsuite and rfsuite.tasks
    local msp = tasks and tasks.msp
    if msp then
        msp.apicore = core
    end

    return core
end

local function cachedFileExists(path)
    if api._fileExistsCache[path] == nil then
        api._fileExistsCache[path] = utils.file_exists(path)
    end
    return api._fileExistsCache[path]
end

local function getChunk(apiName, path)
    local chunk = api._chunkCache[apiName]
    if chunk then
        for i, name in ipairs(api._chunkCacheOrder) do
            if name == apiName then
                table_remove(api._chunkCacheOrder, i)
                break
            end
        end
        table_insert(api._chunkCacheOrder, apiName)
        return chunk
    end

    local loaderFn, err = loadfile(path)
    if not loaderFn then
        utils.log("[api] compile failed for " .. tostring(apiName) .. ": " .. tostring(err), "info")
        return nil
    end

    api._chunkCache[apiName] = loaderFn
    table_insert(api._chunkCacheOrder, apiName)

    if #api._chunkCacheOrder > api._chunkCacheMax then
        local oldest = table_remove(api._chunkCacheOrder, 1)
        api._chunkCache[oldest] = nil
    end

    return loaderFn
end

local function getHelpChunk(apiName, path)
    local chunk = api._helpChunkCache[apiName]
    if chunk then
        for i, name in ipairs(api._helpChunkCacheOrder) do
            if name == apiName then
                table_remove(api._helpChunkCacheOrder, i)
                break
            end
        end
        table_insert(api._helpChunkCacheOrder, apiName)
        return chunk
    end

    local loaderFn, err = loadfile(path)
    if not loaderFn then
        utils.log("[apihelp] compile failed for " .. tostring(apiName) .. ": " .. tostring(err), "info")
        return nil
    end

    api._helpChunkCache[apiName] = loaderFn
    table_insert(api._helpChunkCacheOrder, apiName)

    if #api._helpChunkCacheOrder > api._helpChunkCacheMax then
        local oldest = table_remove(api._helpChunkCacheOrder, 1)
        api._helpChunkCache[oldest] = nil
    end

    return loaderFn
end

local function shouldLoadHelp(loadOpts)
    if type(loadOpts) == "table" and loadOpts.loadHelp ~= nil then
        return loadOpts.loadHelp == true
    end
    if type(loadOpts) == "boolean" then
        return loadOpts == true
    end
    return false
end

local function getHelpFields(apiName)
    if type(apiName) ~= "string" or apiName == "" then return nil end

    local cached = api._helpDataCache[apiName]
    if cached ~= nil then
        return cached or nil
    end

    local helpPath = resolveHelpPath(apiName)
    if not helpPath or not cachedFileExists(helpPath) then
        api._helpDataCache[apiName] = false
        return nil
    end

    local chunk = getHelpChunk(apiName, helpPath)
    if not chunk then
        api._helpDataCache[apiName] = false
        return nil
    end

    local ok, helpData = pcall(chunk)
    if not ok or type(helpData) ~= "table" then
        utils.log("[apihelp] invalid help data for " .. tostring(apiName), "info")
        api._helpDataCache[apiName] = false
        return nil
    end

    local fields = type(helpData.fields) == "table" and helpData.fields or helpData
    if type(fields) ~= "table" then
        api._helpDataCache[apiName] = false
        return nil
    end

    api._helpDataCache[apiName] = fields
    return fields
end

local function injectHelpIntoStructure(apiName, structure)
    if type(structure) ~= "table" then return end

    local helpFields = getHelpFields(apiName)
    if type(helpFields) ~= "table" then return end

    for _, entry in ipairs(structure) do
        if type(entry) ~= "table" then
            goto continue
        end

        local fieldName = entry.field
        if entry.help == nil and type(fieldName) == "string" then
            entry.help = helpFields[fieldName]
        end

        local bitmap = entry.bitmap
        if type(bitmap) == "table" then
            for _, bit in ipairs(bitmap) do
                if type(bit) == "table" then
                    local bitName = bit.field
                    if bit.help == nil and type(bitName) == "string" then
                        local composite = (type(fieldName) == "string") and (fieldName .. "->" .. bitName) or nil
                        bit.help = (composite and helpFields[composite]) or helpFields[bitName]
                    end
                end
            end
        end

        ::continue::
    end
end

local function validateModule(apiName, module)
    if type(module) ~= "table" then
        return nil, "module_not_table"
    end
    if not module.read and not module.write then
        return nil, "module_missing_read_write"
    end

    module.__apiName = apiName
    module.__apiSource = "api"

    if module.read and not module.__rfWrappedRead then
        local original = module.read
        module.read = function(...)
            logApiIo(apiName, "read", "api")
            return original(...)
        end
        module.__rfWrappedRead = true
    end

    if module.write and not module.__rfWrappedWrite then
        local original = module.write
        module.write = function(...)
            logApiIo(apiName, "write", "api")
            return original(...)
        end
        module.__rfWrappedWrite = true
    end

    return module
end

function api.enableDeltaCache(enable)
    if enable == nil then return end
    api._deltaCacheDefault = (enable == true)
end

function api.setApiDeltaCache(apiName, enable)
    if type(apiName) ~= "string" or apiName == "" then return end
    if enable == nil then
        api._deltaCacheByApi[apiName] = nil
        return
    end
    api._deltaCacheByApi[apiName] = (enable == true)
end

function api.isDeltaCacheEnabled(apiName)
    if apiName and api._deltaCacheByApi[apiName] ~= nil then
        return api._deltaCacheByApi[apiName]
    end
    local app = rfsuite and rfsuite.app
    if not (app and app.guiIsRunning) then
        return false
    end
    return api._deltaCacheDefault == true
end

function api.register(apiName, modulePath)
    if type(apiName) ~= "string" or apiName == "" then return false end
    if type(modulePath) ~= "string" or modulePath == "" then return false end
    api._ported[apiName] = modulePath
    api._chunkCache[apiName] = nil
    return true
end

function api.unregister(apiName)
    if type(apiName) ~= "string" or apiName == "" then return false end
    api._ported[apiName] = nil
    api._chunkCache[apiName] = nil
    return true
end

function api.isPorted(apiName)
    if type(apiName) ~= "string" or apiName == "" then return false end
    return cachedFileExists(resolvePath(apiName)) == true
end

function api.load(apiName, loadOpts)
    if type(apiName) ~= "string" or apiName == "" then
        utils.log("[api] invalid api name", "info")
        return nil
    end

    if not ensureCore() then
        utils.log("[api] core unavailable; cannot load " .. tostring(apiName), "info")
        return nil
    end

    local path = resolvePath(apiName)
    if not cachedFileExists(path) then
        utils.log("[api] API file not found: " .. tostring(path), "info")
        return nil
    end

    local chunk = getChunk(apiName, path)
    if not chunk then return nil end

    local apiModule = chunk()
    if shouldLoadHelp(loadOpts) and type(apiModule) == "table" then
        injectHelpIntoStructure(apiName, apiModule.__rfReadStructure)
        if apiModule.__rfWriteStructure ~= apiModule.__rfReadStructure then
            injectHelpIntoStructure(apiName, apiModule.__rfWriteStructure)
        end
    end

    local module, reason = validateModule(apiName, apiModule)
    if not module then
        utils.log("[api] invalid module for " .. tostring(apiName) .. ": " .. tostring(reason), "info")
        return nil
    end

    module.enableDeltaCache = function(enable) api.setApiDeltaCache(apiName, enable) end
    module.isDeltaCacheEnabled = function() return api.isDeltaCacheEnabled(apiName) end

    return module
end

function api.resetApidata()
    local d = api.apidata

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

    api.apidata = {}
end

function api.getFieldHelp(apiName, fieldName)
    if type(apiName) ~= "string" or apiName == "" then return nil end
    if type(fieldName) ~= "string" or fieldName == "" then return nil end

    local helpFields = getHelpFields(apiName)
    if not helpFields then return nil end
    return helpFields[fieldName]
end

function api.clearChunkCache()
    api._chunkCache = {}
    api._chunkCacheOrder = {}
end

function api.clearHelpCache()
    api._helpChunkCache = {}
    api._helpChunkCacheOrder = {}
    api._helpDataCache = {}
end

function api.clearFileExistsCache()
    api._fileExistsCache = {}
end

return api
