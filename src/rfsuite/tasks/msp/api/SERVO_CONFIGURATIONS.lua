--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "SERVO_CONFIGURATIONS"
local MSP_API_CMD_READ = 120
local MSP_API_CMD_WRITE = nil
local MSP_REBUILD_ON_WRITE = true
local MSP_API_SIMULATOR_RESPONSE = {4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0}
local MSP_MIN_BYTES = 1

local MSP_API_STRUCTURE_WRITE = nil
local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

-- LuaFormatter off
local function generateMSPStructureRead(servoCount)
    local MSP_API_STRUCTURE = {{field = "servo_count", type = "U8"}}

    local servo_fields = {
        {field = "mid",   type = "U16", help = "@i18n(api.SERVO_CONFIGURATIONS.mid)@"},
        {field = "min",   type = "U16", help = "@i18n(api.SERVO_CONFIGURATIONS.min)@"},
        {field = "max",   type = "U16", help = "@i18n(api.SERVO_CONFIGURATIONS.max)@"},
        {field = "rneg",  type = "U16", help = "@i18n(api.SERVO_CONFIGURATIONS.rneg)@"},
        {field = "rpos",  type = "U16", help = "@i18n(api.SERVO_CONFIGURATIONS.rpos)@"},
        {field = "rate",  type = "U16", help = "@i18n(api.SERVO_CONFIGURATIONS.rate)@"},
        {field = "speed", type = "U16", help = "@i18n(api.SERVO_CONFIGURATIONS.speed)@"},
        {field = "flags", type = "U16", help = "@i18n(api.SERVO_CONFIGURATIONS.flags)@"}
    }

    for i = 1, servoCount do for _, field in ipairs(servo_fields) do table.insert(MSP_API_STRUCTURE, {field = string.format("servo_%d_%s", i, field.field), type = field.type, apiVersion = 12.07}) end end

    return MSP_API_STRUCTURE
end
-- LuaFormatter on

local function processMSPData(buf, MSP_API_STRUCTURE_READ)
    local data = {servos = {}}

    if not buf or type(buf) ~= "table" then return nil end

    for i, field in ipairs(MSP_API_STRUCTURE_READ) do
        local baseName, servoIndex = field.field:match("servo_(%d+)_(.+)")
        local value = 0

        if field.type == "U8" then
            value = buf[i] or 0
        elseif field.type == "U16" then
            value = (buf[i] or 0) + ((buf[i + 1] or 0) * 256)
        end

        if baseName and servoIndex then
            local keyIndex = tonumber(baseName) - 1

            if not data.servos[keyIndex] then data.servos[keyIndex] = {} end

            data.servos[keyIndex][servoIndex] = value
        else

            data[field.field] = value
        end
    end

    return data
end

local lastWriteUUID = nil

local writeDoneRegistry = setmetatable({}, {__mode = "kv"})

local function processReplyStaticRead(self, buf)
    core.parseMSPData(API_NAME, buf, self.structure, nil, nil, function(result)
        mspData = result
        if #buf >= (self.minBytes or 0) then
            local getComplete = self.getCompleteHandler
            if getComplete then
                local complete = getComplete()
                if complete then complete(self, buf) end
            end
        end
    end)
end

local function processReplyStaticWrite(self, buf)
    mspWriteComplete = true

    if self.uuid then writeDoneRegistry[self.uuid] = true end

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

local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os.clock())
    lastWriteUUID = uuid

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function readComplete() return mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
