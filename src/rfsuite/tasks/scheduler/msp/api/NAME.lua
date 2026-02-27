--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local API_NAME = "NAME"
local MSP_API_CMD_READ = 10
local MSP_API_CMD_WRITE = 11
local MAX_NAME_LENGTH = 16
local MSP_MIN_BYTES = 0
local MSP_API_SIMULATOR_RESPONSE = {80, 105, 108, 111, 116}

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
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

local function parseName(buf)
    local helper = getMspHelper()
    if not helper then return nil end

    local name = ""
    buf.offset = 1
    while #name < MAX_NAME_LENGTH do
        local ch = helper.readU8(buf)
        if ch == nil or ch == 0 then break end
        name = name .. string.char(ch)
    end

    return {
        parsed = {name = name},
        buffer = buf,
        receivedBytesCount = #buf
    }
end

local function processReplyStaticRead(self, buf)
    mspData = parseName(buf)
    if not mspData then
        dispatchError(self, "parse_failed")
        return
    end
    local onComplete = completeHandler
    if onComplete then onComplete(self, buf) end
end

local function processReplyStaticWrite(self, buf)
    mspWriteComplete = true
    local onComplete = completeHandler
    if onComplete then onComplete(self, buf) end
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

local function write(suppliedPayload)
    local payload = suppliedPayload
    if not payload then
        local nameValue = payloadData.name
        if nameValue == nil and mspData and mspData.parsed then
            nameValue = mspData.parsed.name
        end
        if nameValue == nil then nameValue = "" end
        if type(nameValue) ~= "string" then nameValue = tostring(nameValue) end

        payload = {}
        local length = math.min(#nameValue, MAX_NAME_LENGTH)
        for i = 1, length do
            payload[#payload + 1] = string.byte(nameValue, i)
        end
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        apiname = API_NAME,
        payload = payload,
        processReply = processReplyStaticWrite,
        errorHandler = errorHandlerStatic,
        simulatorResponse = {},
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT
    }
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData.parsed then return mspData.parsed[fieldName] end
    return nil
end

local function setValue(fieldName, value)
    payloadData[fieldName] = value
end

local function readComplete()
    return mspData ~= nil
end

local function writeComplete()
    return mspWriteComplete
end

local function resetWriteStatus()
    mspWriteComplete = false
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
    write = write,
    setRebuildOnWrite = setRebuildOnWrite,
    readComplete = readComplete,
    writeComplete = writeComplete,
    readValue = readValue,
    setValue = setValue,
    resetWriteStatus = resetWriteStatus,
    setCompleteHandler = setCompleteHandler,
    setErrorHandler = setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}
