--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "REBOOT"
local MSP_API_CMD_WRITE = 68
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    {field = "rebootMode", type = "U8", apiVersion = 12.06, simResponse = {0}}
}
-- LuaFormatter on

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
    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os_clock())

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {write = write, setRebuildOnWrite = setRebuildOnWrite, writeComplete = writeComplete, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, setUUID = setUUID, setTimeout = setTimeout}
