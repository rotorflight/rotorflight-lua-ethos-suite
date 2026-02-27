--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local API_NAME = "UID"
local MSP_API_CMD_READ = 160
local MSP_MIN_BYTES = 12
local MSP_API_SIMULATOR_RESPONSE = {43, 0, 34, 0, 9, 81, 51, 52, 52, 56, 53, 49}

local mspData = nil
local completeHandler = nil
local errorHandler = nil
local MSP_API_UUID = nil
local MSP_API_MSG_TIMEOUT = nil
local MSP_REBUILD_ON_WRITE = false

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
    local u0 = helper.readU32(buf)
    local u1 = helper.readU32(buf)
    local u2 = helper.readU32(buf)
    if u0 == nil or u1 == nil or u2 == nil then return nil end

    return {
        parsed = {
            U_ID_0 = u0,
            U_ID_1 = u1,
            U_ID_2 = u2
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

local function readValue(fieldName)
    if mspData and mspData.parsed then return mspData.parsed[fieldName] end
    return nil
end

local function readComplete()
    return mspData ~= nil and mspData.buffer ~= nil and #mspData.buffer >= MSP_MIN_BYTES
end

local function data() return mspData end

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
local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {
    read = read,
    setRebuildOnWrite = setRebuildOnWrite,
    readComplete = readComplete,
    readValue = readValue,
    setCompleteHandler = setCompleteHandler,
    setErrorHandler = setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}
