--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local API_NAME = "FC_VERSION"
local MSP_API_CMD_READ = 3
local MSP_MIN_BYTES = 3
local MSP_API_SIMULATOR_RESPONSE = {4, 5, 1}

local mspData = nil
local completeHandler = nil
local errorHandler = nil
local MSP_API_UUID = nil
local MSP_API_MSG_TIMEOUT = nil
local string_format = string.format
local tonumber = tonumber

local function getMspHelper()
    local tasks = rfsuite and rfsuite.tasks
    local msp = tasks and tasks.msp
    return msp and msp.mspHelper
end

local function dispatchError(self, err)
    local onError = errorHandler
    if onError then onError(self, err) end
end

local function parse(buf)
    local helper = getMspHelper()
    if not helper then return nil end

    buf.offset = 1
    local major = helper.readU8(buf)
    local minor = helper.readU8(buf)
    local patch = helper.readU8(buf)
    if major == nil or minor == nil or patch == nil then return nil end

    return {
        parsed = {
            version_major = major,
            version_minor = minor,
            version_patch = patch
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

local function processReplyStaticRead(self, buf)
    mspData = parse(buf)
    if not mspData then
        dispatchError(self, "parse_failed")
        return
    end
    if #buf >= MSP_MIN_BYTES then
        local onComplete = completeHandler
        if onComplete then onComplete(self, buf) end
    end
end

local function errorHandlerStatic(self, err)
    dispatchError(self, err)
end

local function read()
    local message = {
        command = MSP_API_CMD_READ,
        apiname = API_NAME,
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
    local parsed = mspData.parsed
    return string_format("%d.%d.%d", parsed.version_major, parsed.version_minor, parsed.version_patch)
end

local function readRfVersion()
    local MAJOR_OFFSET = 2
    local MINOR_OFFSET = 3

    local raw = readVersion()
    if not raw then return nil end

    local maj, min, patch = raw:match("(%d+)%.(%d+)%.(%d+)")
    maj = tonumber(maj) - MAJOR_OFFSET
    min = tonumber(min) - MINOR_OFFSET
    patch = tonumber(patch)

    if maj < 0 or min < 0 then return raw end
    return string_format("%d.%d.%d", maj, min, patch)
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
    readRfVersion = readRfVersion,
    readValue = readValue,
    setCompleteHandler = setCompleteHandler,
    setErrorHandler = setErrorHandler,
    setUUID = setUUID,
    setTimeout = setTimeout
}
