--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local API_NAME = "API_VERSION"
local MSP_API_CMD_READ = 1
local MSP_MIN_BYTES = 3

local MSP_API_SIMULATOR_RESPONSE = rfsuite.utils.splitVersionStringToNumbers(
    rfsuite.config.supportedMspApiVersion[rfsuite.preferences.developer.apiversion]
)

local MSP_API_STRUCTURE_READ = {
    {field = "version_command", type = "U8", help = "@i18n(api.API_VERSION.version_command)@"},
    {field = "version_major",   type = "U8", help = "@i18n(api.API_VERSION.version_major)@"},
    {field = "version_minor",   type = "U8", help = "@i18n(api.API_VERSION.version_minor)@"}
}

local mspData = nil
local completeHandler = nil
local errorHandler = nil
local MSP_API_UUID = nil
local MSP_API_MSG_TIMEOUT = nil

local function getMspHelper()
    local tasks = rfsuite and rfsuite.tasks
    local msp = tasks and tasks.msp
    return msp and msp.mspHelper
end

local function parseVersion(buf)
    local helper = getMspHelper()
    if not helper then return nil end

    buf.offset = 1
    local version_command = helper.readU8(buf)
    local version_major = helper.readU8(buf)
    local version_minor = helper.readU8(buf)
    if version_command == nil or version_major == nil or version_minor == nil then
        return nil
    end

    return {
        parsed = {
            version_command = version_command,
            version_major = version_major,
            version_minor = version_minor
        },
        buffer = buf,
        structure = MSP_API_STRUCTURE_READ,
        receivedBytesCount = #buf
    }
end

local function processReplyStaticRead(self, buf)
    mspData = parseVersion(buf)
    if not mspData then
        local onError = errorHandler
        if onError then onError(self, "parse_failed") end
        return
    end

    if #buf >= MSP_MIN_BYTES then
        local onComplete = completeHandler
        if onComplete then onComplete(self, buf) end
    end
end

local function errorHandlerStatic(self, err)
    local onError = errorHandler
    if onError then onError(self, err) end
end

local function read()
    local message = {
        command = MSP_API_CMD_READ,
        apiname = API_NAME,
        structure = MSP_API_STRUCTURE_READ,
        minBytes = MSP_MIN_BYTES,
        processReply = processReplyStaticRead,
        errorHandler = errorHandlerStatic,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT
    }
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function data() return mspData end

local function readComplete()
    return mspData ~= nil and mspData.buffer ~= nil and #mspData.buffer >= MSP_MIN_BYTES
end

local function readVersion()
    if not mspData or not mspData.parsed then return nil end
    return mspData.parsed.version_major + (mspData.parsed.version_minor / 100)
end

local function readValue(fieldName)
    if mspData and mspData.parsed then return mspData.parsed[fieldName] end
    return nil
end

local function setCompleteHandler(fn)
    if type(fn) == "function" then
        completeHandler = fn
    else
        error("Complete handler requires function")
    end
end

local function setErrorHandler(fn)
    if type(fn) == "function" then
        errorHandler = fn
    else
        error("Error handler requires function")
    end
end

local function setUUID(uuid) MSP_API_UUID = uuid end
local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end
local function setRebuildOnWrite(_) end

return {
    data = data,
    read = read,
    setRebuildOnWrite = setRebuildOnWrite,
    readComplete = readComplete,
    readVersion = readVersion,
    readValue = readValue,
    setCompleteHandler = setCompleteHandler,
    setErrorHandler = setErrorHandler,
    setUUID = setUUID,
    setTimeout = setTimeout
}
