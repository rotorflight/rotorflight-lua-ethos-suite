--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local API_NAME = "RTC"
local MSP_API_CMD_READ = 247
local MSP_API_CMD_WRITE = 246
local MSP_MIN_BYTES = 9
local MSP_API_SIMULATOR_RESPONSE = {233, 7, 1, 1, 0, 0, 0, 0, 0}

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local completeHandler = nil
local errorHandler = nil
local MSP_API_UUID = nil
local MSP_API_MSG_TIMEOUT = nil
local MSP_REBUILD_ON_WRITE = false
local os_time = os.time

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
    local year = helper.readU16(buf)
    local month = helper.readU8(buf)
    local day = helper.readU8(buf)
    local hours = helper.readU8(buf)
    local minutes = helper.readU8(buf)
    local seconds = helper.readU8(buf)
    local milliseconds = helper.readU16(buf)
    if year == nil or month == nil or day == nil or hours == nil or minutes == nil or seconds == nil or milliseconds == nil then
        return nil
    end

    return {
        parsed = {
            year = year,
            month = month,
            day = day,
            hours = hours,
            minutes = minutes,
            seconds = seconds,
            milliseconds = milliseconds
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

local function buildWritePayload()
    local helper = getMspHelper()
    if not helper then return nil end
    local payload = {}
    local seconds = payloadData.seconds
    local milliseconds = payloadData.milliseconds
    if seconds == nil then seconds = os_time() end
    if milliseconds == nil then milliseconds = 0 end
    helper.writeU32(payload, seconds)
    helper.writeU16(payload, milliseconds)
    return payload
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
    local payload = suppliedPayload or buildWritePayload()
    if not payload then
        dispatchError(nil, "build_payload_failed")
        return false, "build_payload_failed"
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
    return mspData ~= nil and mspData.buffer ~= nil and #mspData.buffer >= MSP_MIN_BYTES
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
