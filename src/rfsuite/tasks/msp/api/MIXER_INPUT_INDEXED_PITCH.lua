--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html

  This module defined FIXED_INDEX that is used to support indexed based MSP APIs.
  It is a specialised API module that sends a paramter index as part of the payload

]]--

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "MIXER_INPUT_INDEXED_PITCH"
local MSP_API_CMD_READ = 170
local MSP_API_CMD_WRITE = 171
local MSP_REBUILD_ON_WRITE = true

local FIXED_INDEX = 2

-- LuaFormatter off
local MSP_API_STRUCTURE_READ = {
    { field = "rate", type = "U16", apiVersion = 12.09, simResponse = { 250, 0 }, tableEthos = { [1] = { "@i18n(api.MIXER_INPUT.tbl_normal)@",   250 }, [2] = { "@i18n(api.MIXER_INPUT.tbl_reversed)@", 65286 },}},
    { field = "min",  type = "U16", apiVersion = 12.09, simResponse = { 30, 251 } },
    { field = "max",  type = "U16", apiVersion = 12.09, simResponse = { 226, 4 } },
}
-- LuaFormatter on

local _, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    { field = "index", type = "U8"  },
    { field = "rate",  type = "U16" },
    { field = "min",   type = "U16" },
    { field = "max",   type = "U16" },
}
-- LuaFormatter on

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local function callComplete(self, buf)
    local getComplete = self.getCompleteHandler
    if getComplete then
        local complete = getComplete()
        if complete then complete(self, buf) end
    end
end

local function callError(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

local function processReplyRead(self, buf)
    core.parseMSPData(API_NAME, buf, MSP_API_STRUCTURE_READ, nil, nil, function(result)
        mspData = result
        if #buf >= (self.minBytes or 0) then
            callComplete(self, buf)
        end
    end)
end

local function processReplyWrite(self, buf)
    mspWriteComplete = true
    callComplete(self, buf)
end

local function read()
    local message = {
        command = MSP_API_CMD_READ,
        payload = { FIXED_INDEX },               -- << fixed idx read
        structure = MSP_API_STRUCTURE_READ,
        minBytes = MSP_MIN_BYTES,
        processReply = processReplyRead,
        errorHandler = function(self, buf) callError(self, buf) end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = (MSP_API_UUID or API_NAME) .. ":R:" .. tostring(FIXED_INDEX),
        timeout = MSP_API_MSG_TIMEOUT,
        getCompleteHandler = handlers.getCompleteHandler,
        getErrorHandler = handlers.getErrorHandler,
        mspData = nil,
        isWrite = false,
    }
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if suppliedPayload then
        local message = {
            command = MSP_API_CMD_WRITE,
            payload = suppliedPayload,
            processReply = processReplyWrite,
            errorHandler = function(self, buf) callError(self, buf) end,
            simulatorResponse = {},
            uuid = (MSP_API_UUID or API_NAME) .. ":R:" .. tostring(FIXED_INDEX),
            timeout = MSP_API_MSG_TIMEOUT,
            getCompleteHandler = handlers.getCompleteHandler,
            getErrorHandler = handlers.getErrorHandler,
            isWrite = true,
        }
        rfsuite.tasks.msp.mspQueue:add(message)
        return
    end

    -- Preserve min/max if caller only changed rate (typical for direction)
    local curRate = (mspData and mspData.parsed and mspData.parsed.rate) or 0
    local curMin  = (mspData and mspData.parsed and mspData.parsed.min)  or 0
    local curMax  = (mspData and mspData.parsed and mspData.parsed.max)  or 0

    local v = {
        index = FIXED_INDEX,
        rate  = (payloadData.rate ~= nil) and payloadData.rate or curRate,
        min   = (payloadData.min  ~= nil) and payloadData.min  or curMin,
        max   = (payloadData.max  ~= nil) and payloadData.max  or curMax,
    }

    local payload = core.buildFullPayload(API_NAME, v, MSP_API_STRUCTURE_WRITE)

    local message = {
        command = MSP_API_CMD_WRITE,
        payload = payload,
        processReply = function(self, buf)
            -- Update local cache immediately so UI reflects change without reread
            mspData = mspData or { parsed = {} }
            mspData.parsed.rate = v.rate
            mspData.parsed.min  = v.min
            mspData.parsed.max  = v.max
            processReplyWrite(self, buf)
        end,
        errorHandler = function(self, buf) callError(self, buf) end,
        simulatorResponse = {},
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT,
        getCompleteHandler = handlers.getCompleteHandler,
        getErrorHandler = handlers.getErrorHandler,
    }

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData.parsed and mspData.parsed[fieldName] ~= nil then
        return mspData.parsed[fieldName]
    end
    return nil
end

local function setValue(fieldName, value)
    payloadData[fieldName] = value
end

local function readComplete()
    return mspData ~= nil and mspData.buffer and #mspData.buffer >= MSP_MIN_BYTES
end

local function writeComplete() return mspWriteComplete end
local function resetWriteStatus() mspWriteComplete = false end
local function data() return mspData end
local function setUUID(uuid) MSP_API_UUID = uuid end
local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

return {
    read = read,
    write = write,
    readComplete = readComplete,
    writeComplete = writeComplete,
    readValue = readValue,
    setValue = setValue,
    resetWriteStatus = resetWriteStatus,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout,
}
