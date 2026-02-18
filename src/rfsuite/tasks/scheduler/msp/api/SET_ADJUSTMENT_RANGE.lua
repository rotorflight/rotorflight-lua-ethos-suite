--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "SET_ADJUSTMENT_RANGE"
local MSP_API_CMD_WRITE = 53
local MSP_REBUILD_ON_WRITE = false

local mspWriteComplete = false
local payloadData = {}
local os_clock = os.clock
local tostring = tostring
local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local function processReplyStaticWrite(self, buf)
    mspWriteComplete = true
    local getComplete = self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function errorHandlerStatic(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

local function write(suppliedPayload)
    local payload = suppliedPayload or payloadData.payload
    if type(payload) ~= "table" then return false, "missing_payload" end

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os_clock())
    local message = {
        command = MSP_API_CMD_WRITE,
        apiname = API_NAME,
        payload = payload,
        processReply = processReplyStaticWrite,
        errorHandler = errorHandlerStatic,
        simulatorResponse = {},
        uuid = uuid,
        timeout = MSP_API_MSG_TIMEOUT,
        getCompleteHandler = handlers.getCompleteHandler,
        getErrorHandler = handlers.getErrorHandler
    }
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function setValue(fieldName, value) payloadData[fieldName] = value end
local function writeComplete() return mspWriteComplete end
local function resetWriteStatus() mspWriteComplete = false end
local function setUUID(uuid) MSP_API_UUID = uuid end
local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end
local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end
local function readComplete() return false end
local function readValue() return nil end
local function data() return nil end

return {
    write = write,
    setValue = setValue,
    writeComplete = writeComplete,
    resetWriteStatus = resetWriteStatus,
    setRebuildOnWrite = setRebuildOnWrite,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    setUUID = setUUID,
    setTimeout = setTimeout,
    readComplete = readComplete,
    readValue = readValue,
    data = data
}
