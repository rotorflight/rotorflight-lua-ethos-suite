--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "SBUS_OUTPUT_CONFIG"

-- Indexed (single-channel) SBUS output config
-- READ  (MSP_GET_SBUS_OUTPUT_CONFIG): payload = { index }
-- WRITE (MSP_SET_SBUS_OUTPUT_CONFIG): payload = { index, source_type, source_index, source_range_low, source_range_high }
local MSP_API_CMD_READ = 157
local MSP_API_CMD_WRITE = 153

-- Single-channel writes do not require table rebuild semantics.
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
-- Note: This API is intentionally "bespoke" (like GET_MIXER_INPUT_*).
--       We keep the structure small and do not generate N-channel fields.
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "source_type",       type = "U8",  apiVersion = 12.06, simResponse = { 1 },        min = 0,     max = 16,    help = "@i18n(api.msp.sbus_output_config.type)@" },
    { field = "source_index",      type = "U8",  apiVersion = 12.06, simResponse = { 0 },        min = 0,     max = 15,    help = "@i18n(api.msp.sbus_output_config.index)@" },
    { field = "source_range_low",  type = "S16", apiVersion = 12.06, simResponse = { 24, 252 },  min = -2000, max = 2000,  help = "@i18n(api.msp.sbus_output_config.range_low)@" },
    { field = "source_range_high", type = "S16", apiVersion = 12.06, simResponse = { 232, 3 },   min = -2000, max = 2000,  help = "@i18n(api.msp.sbus_output_config.range_high)@" },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    { field = "index",             type = "U8",  apiVersion = 12.06, min = 0, max = 255 },
    { field = "source_type",       type = "U8",  apiVersion = 12.06, min = 0, max = 16  },
    { field = "source_index",      type = "U8",  apiVersion = 12.06, min = 0, max = 15  },
    { field = "source_range_low",  type = "S16", apiVersion = 12.06, min = -2000, max = 2000 },
    { field = "source_range_high", type = "S16", apiVersion = 12.06, min = -2000, max = 2000 },
}
-- LuaFormatter on

local mspData = nil
local mspWriteComplete = false
local payloadData = {}

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local lastWriteUUID = nil
local writeDoneRegistry = setmetatable({}, { __mode = "kv" })

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

-- Read one channel (index is 0-based, per firmware)
local function read(index)
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local idx = index
    if idx == nil then idx = payloadData.index end
    if idx == nil then idx = rfsuite.currentSbusServoIndex end
    if idx == nil then idx = 0 end

    local uuid = MSP_API_UUID
    local message = {
        command = MSP_API_CMD_READ,
        apiname = API_NAME,
        payload = { tonumber(idx) or 0 },
        structure = MSP_API_STRUCTURE_READ,
        minBytes = MSP_MIN_BYTES,
        processReply = processReplyStaticRead,
        errorHandler = errorHandlerStatic,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = uuid,
        timeout = MSP_API_MSG_TIMEOUT,
        getCompleteHandler = handlers.getCompleteHandler,
        getErrorHandler = handlers.getErrorHandler,
        mspData = nil
    }

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    -- Ensure index is present; forms typically set this.
    local idx = payloadData.index
    if idx == nil then idx = rfsuite.currentSbusServoIndex end
    if idx == nil then
        rfsuite.utils.log("SBUS_OUTPUT_CONFIG.write requires payloadData.index (0-based channel index)", "debug")
        return
    end

    payloadData.index = idx

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or (rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid()) or tostring(os.clock())
    lastWriteUUID = uuid

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
    return mspData ~= nil and mspData.buffer ~= nil and #mspData.buffer >= MSP_MIN_BYTES
end

local function writeComplete()
    return mspWriteComplete
end

local function resetWriteStatus()
    mspWriteComplete = false
end

local function data()
    return mspData
end

local function setUUID(uuid)
    MSP_API_UUID = uuid
end

local function setTimeout(timeout)
    MSP_API_MSG_TIMEOUT = timeout
end

local function setRebuildOnWrite(rebuild)
    MSP_REBUILD_ON_WRITE = rebuild
end

return {
    read = read,
    write = write,
    setRebuildOnWrite = setRebuildOnWrite,
    readComplete = readComplete,
    writeComplete = writeComplete,
    readValue = readValue,
    setValue = setValue,
    resetWriteStatus = resetWriteStatus,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}
