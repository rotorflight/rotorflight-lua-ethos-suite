--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "RXFAIL_CONFIG"
local MSP_API_CMD_READ = 77
local MSP_API_CMD_WRITE = 78
local MSP_REBUILD_ON_WRITE = true

local MAX_SUPPORTED_RC_CHANNEL_COUNT = 18
local math_floor = math.floor

local MSP_API_STRUCTURE_READ_DATA = {}
for i = 1, MAX_SUPPORTED_RC_CHANNEL_COUNT do
    local mandatory = (i == 1)
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = {
        field = "channel_" .. i .. "_mode",
        type = "U8",
        apiVersion = 12.06,
        mandatory = mandatory,
        simResponse = {0},
        table = {
            [0] = "@i18n(api.RXFAIL_CONFIG.tbl_auto)@",
            [1] = "@i18n(api.RXFAIL_CONFIG.tbl_hold)@",
            [2] = "@i18n(api.RXFAIL_CONFIG.tbl_set)@"
        },
        help = "@i18n(api.RXFAIL_CONFIG.channel_mode)@"
    }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = {
        field = "channel_" .. i .. "_value",
        type = "U16",
        apiVersion = 12.06,
        mandatory = mandatory,
        simResponse = {220, 5},
        min = 885,
        max = 2115,
        default = 1500,
        unit = "us",
        help = "@i18n(api.RXFAIL_CONFIG.channel_value)@"
    }
end

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    { field = "index", type = "U8"  },
    { field = "mode",  type = "U8"  },
    { field = "value", type = "U16" },
}
-- LuaFormatter on

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}
local os_clock = os.clock
local tostring = tostring
local log = rfsuite.utils.log

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local lastWriteUUID = nil

local writeDoneRegistry = setmetatable({}, {__mode = "kv"})
local stagedWritePos = 1
local stagedWriteUUID = nil
local stagedHasReadData = false
local processReplyStaticWrite
local errorHandlerStatic

local function emitWriteComplete(self, buf)
    mspWriteComplete = true
    stagedWriteUUID = nil
    stagedWritePos = 1
    stagedHasReadData = false
    local getComplete = self and self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function nextStagedWriteItem()
    while stagedWritePos <= MAX_SUPPORTED_RC_CHANNEL_COUNT do
        local channelIndex = stagedWritePos
        stagedWritePos = stagedWritePos + 1

        local modeField = "channel_" .. channelIndex .. "_mode"
        local valueField = "channel_" .. channelIndex .. "_value"

        local mode = payloadData[modeField]
        if mode == nil and stagedHasReadData then mode = mspData.parsed[modeField] end
        if mode == nil then mode = 0 end

        local value = payloadData[valueField]
        if value == nil and stagedHasReadData then value = mspData.parsed[valueField] end
        if value == nil then value = 1500 end

        local modeNum = math_floor(tonumber(mode) or 0)
        local valueNum = math_floor(tonumber(value) or 1500)

        local changed = true
        if stagedHasReadData then
            local prevMode = math_floor(tonumber(mspData.parsed[modeField]) or 0)
            local prevValue = math_floor(tonumber(mspData.parsed[valueField]) or 0)
            if prevMode == modeNum and prevValue == valueNum then
                changed = false
            end
        end

        if changed then
            local writeData = {
                index = channelIndex - 1,
                mode = modeNum,
                value = valueNum
            }
            local payload = core.buildFullPayload(API_NAME, writeData, MSP_API_STRUCTURE_WRITE)
            return {index = channelIndex - 1, payload = payload}
        end
    end

    return nil
end

local function queueNextStagedWrite(self)
    if not stagedWriteUUID then
        emitWriteComplete(self, nil)
        return true
    end

    local item = nextStagedWriteItem()
    if not item then
        emitWriteComplete(self, nil)
        return true
    end

    local message = {
        command = MSP_API_CMD_WRITE,
        apiname = API_NAME,
        payload = item.payload,
        processReply = processReplyStaticWrite,
        errorHandler = errorHandlerStatic,
        simulatorResponse = {},
        uuid = tostring(stagedWriteUUID) .. "-" .. tostring(item.index + 1),
        timeout = MSP_API_MSG_TIMEOUT,
        getCompleteHandler = handlers.getCompleteHandler,
        getErrorHandler = handlers.getErrorHandler
    }

    local ok, reason = rfsuite.tasks.msp.mspQueue:add(message)
    if not ok then
        mspWriteComplete = true
        stagedWriteUUID = nil
        stagedWritePos = 1
        stagedHasReadData = false
        local getError = message.getErrorHandler
        if getError then
            local err = getError()
            if err then err(message, reason) end
        end
        return false, reason
    end

    return true
end

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

processReplyStaticWrite = function(self, buf)
    if self.uuid then writeDoneRegistry[self.uuid] = true end

    if stagedWriteUUID then
        local ok = queueNextStagedWrite(self)
        if ok then return end
    end

    emitWriteComplete(self, buf)
end

errorHandlerStatic = function(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

local function read()
    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os_clock())
    lastWriteUUID = uuid

    if suppliedPayload then
        mspWriteComplete = false
        stagedWriteUUID = nil
        stagedWritePos = 1
        stagedHasReadData = false
        local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = suppliedPayload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}
        return rfsuite.tasks.msp.mspQueue:add(message)
    end

    mspWriteComplete = false
    stagedWritePos = 1
    stagedWriteUUID = uuid
    stagedHasReadData = mspData and mspData.parsed and true or false

    return queueNextStagedWrite({getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler})
end

local function readValue(fieldName)
    if mspData and mspData.parsed then return mspData.parsed[fieldName] end
    return nil
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function readComplete() return mspData ~= nil and #mspData.buffer >= MSP_MIN_BYTES end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
