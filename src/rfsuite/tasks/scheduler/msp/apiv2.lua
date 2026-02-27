--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local arg = {...}
local apiv1 = arg[1]

local loadfile = loadfile
local type = type
local tostring = tostring
local pairs = pairs
local string_format = string.format

local utils = rfsuite.utils

local api2 = {}

api2._ported = {}
api2._chunks = {}

local defaultApiPath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/apiv2/api/"

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

local function wrapModuleIO(apiName, module, source)
    if type(module) ~= "table" then return module end
    module.__apiName = apiName
    module.__apiSource = source or module.__apiSource or "apiv2"

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

local function ensureApiv1()
    if apiv1 then return apiv1 end
    local tasks = rfsuite and rfsuite.tasks
    local msp = tasks and tasks.msp
    apiv1 = msp and msp.apiv1
    return apiv1
end

local function normalizePath(value)
    if type(value) ~= "string" or value == "" then return nil end
    if value:sub(1, 8) == "SCRIPTS:/" then
        return value
    end
    return defaultApiPath .. value
end

local function validateModule(apiName, module)
    if type(module) ~= "table" then
        return nil, "module_not_table"
    end
    if not module.read and not module.write then
        return nil, "module_missing_read_write"
    end
    return wrapModuleIO(apiName, module, "apiv2")
end

local function loadPortedApi(apiName)
    local path = normalizePath(api2._ported[apiName]) or (defaultApiPath .. apiName .. ".lua")
    if not utils.file_exists(path) then
        return nil, "not_ported"
    end

    local fn = api2._chunks[apiName]
    local err
    if not fn then
        fn, err = loadfile(path)
        if not fn then
            utils.log("[apiv2] compile failed for " .. tostring(apiName) .. ": " .. tostring(err), "info")
            return nil, "compile_failed"
        end
        api2._chunks[apiName] = fn
    end

    local ok, moduleOrErr = pcall(fn)
    if not ok then
        utils.log("[apiv2] load failed for " .. tostring(apiName) .. ": " .. tostring(moduleOrErr), "info")
        return nil, "load_failed"
    end

    local module, reason = validateModule(apiName, moduleOrErr)
    if not module then
        utils.log("[apiv2] invalid module for " .. tostring(apiName) .. ": " .. tostring(reason), "info")
        return nil, reason
    end

    return module
end

function api2.register(apiName, modulePath)
    if type(apiName) ~= "string" or apiName == "" then return false end
    if type(modulePath) ~= "string" or modulePath == "" then return false end
    api2._ported[apiName] = modulePath
    api2._chunks[apiName] = nil
    return true
end

function api2.unregister(apiName)
    if type(apiName) ~= "string" or apiName == "" then return false end
    api2._ported[apiName] = nil
    api2._chunks[apiName] = nil
    return true
end

function api2.isPorted(apiName)
    if type(apiName) ~= "string" or apiName == "" then return false end
    local path = normalizePath(api2._ported[apiName]) or (defaultApiPath .. apiName .. ".lua")
    return utils.file_exists(path) == true
end

function api2.clearPortedCache()
    for k in pairs(api2._chunks) do api2._chunks[k] = nil end
end

function api2.load(apiName)
    local module = loadPortedApi(apiName)
    if module then return module end

    local legacy = ensureApiv1()
    if legacy and legacy.load then
        return legacy.load(apiName)
    end

    utils.log("[apiv2] no fallback loader for " .. tostring(apiName), "info")
    return nil
end

-- Compatibility shims (existing code expects these on tasks.msp.api)
function api2.enableDeltaCache(enable)
    local legacy = ensureApiv1()
    if legacy and legacy.enableDeltaCache then
        return legacy.enableDeltaCache(enable)
    end
end

function api2.setApiDeltaCache(apiName, enable)
    local legacy = ensureApiv1()
    if legacy and legacy.setApiDeltaCache then
        return legacy.setApiDeltaCache(apiName, enable)
    end
end

function api2.isDeltaCacheEnabled(apiName)
    local legacy = ensureApiv1()
    if legacy and legacy.isDeltaCacheEnabled then
        return legacy.isDeltaCacheEnabled(apiName)
    end
    return false
end

function api2.resetApidata()
    local legacy = ensureApiv1()
    if legacy and legacy.resetApidata then
        return legacy.resetApidata()
    end
end

function api2.clearChunkCache()
    api2.clearPortedCache()
    local legacy = ensureApiv1()
    if legacy and legacy.clearChunkCache then
        return legacy.clearChunkCache()
    end
end

function api2.clearFileExistsCache()
    local legacy = ensureApiv1()
    if legacy and legacy.clearFileExistsCache then
        return legacy.clearFileExistsCache()
    end
end

setmetatable(api2, {
    __index = function(_, k)
        local legacy = ensureApiv1()
        if legacy then return legacy[k] end
    end
})

local function syncApidataRef()
    local legacy = ensureApiv1()
    if legacy then
        api2.apidata = legacy.apidata
    else
        api2.apidata = api2.apidata or {}
    end
end

syncApidataRef()

return api2
