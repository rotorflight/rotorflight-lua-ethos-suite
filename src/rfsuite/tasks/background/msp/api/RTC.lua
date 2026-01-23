--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "RTC"
local MSP_API_CMD_WRITE = 246

-- LuaFormatter off
local MSP_STRUCTURE_WRITE = {
    {field = "seconds", type = "U32"}, {field = "milliseconds", type = "U16"}
}
-- LuaFormatter on

local mspWriteComplete = false

local payloadData = {}
local defaultData = {}

local handlers = core.createHandlers()

local function processReplyStaticWrite(self, buf)

    mspWriteComplete = true
    local getComplete = self and self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function errorHandlerStatic(self, buf)
    local getError = self and self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local function getDefaults() return {seconds = os.time(), milliseconds = 0} end

local function write()
    local defaults = getDefaults()

    for _, field in ipairs(MSP_STRUCTURE_WRITE) do
        if payloadData[field.field] == nil then
            if defaults[field.field] ~= nil then
                payloadData[field.field] = defaults[field.field]
            else
                error("Missing value for field: " .. field.field)
                return
            end
        end
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        apiname = API_NAME,
        payload = {},
        processReply = function(self, buf)
            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then completeHandler(self, buf) end
            mspWriteComplete = true
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = {},
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT
    }

    for _, field in ipairs(MSP_STRUCTURE_WRITE) do

        local byteorder = field.byteorder or "little"

        if field.type == "U32" then
            rfsuite.tasks.msp.mspHelper.writeU32(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "S32" then
            rfsuite.tasks.msp.mspHelper.writeU32(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "U24" then
            rfsuite.tasks.msp.mspHelper.writeU24(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "S24" then
            rfsuite.tasks.msp.mspHelper.writeU24(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "U16" then
            rfsuite.tasks.msp.mspHelper.writeU16(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "S16" then
            rfsuite.tasks.msp.mspHelper.writeU16(message.payload, payloadData[field.field], byteorder)
        elseif field.type == "U8" then
            rfsuite.tasks.msp.mspHelper.writeU8(message.payload, payloadData[field.field])
        elseif field.type == "S8" then
            rfsuite.tasks.msp.mspHelper.writeU8(message.payload, payloadData[field.field])
        end
    end

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function setValue(fieldName, value)
    for _, field in ipairs(MSP_STRUCTURE_WRITE) do
        if field.field == fieldName then
            payloadData[fieldName] = value
            return true
        end
    end
    error("Invalid field name: " .. fieldName)
end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {write = write, setRebuildOnWrite = setRebuildOnWrite, setValue = setValue, writeComplete = writeComplete, resetWriteStatus = resetWriteStatus, getDefaults = getDefaults, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
