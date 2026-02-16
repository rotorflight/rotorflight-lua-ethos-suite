--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "GET_MIXER_INPUT_YAW"
local MSP_API_CMD_READ = 174
local MSP_API_CMD_WRITE = 171
local MSP_REBUILD_ON_WRITE = true

local FIXED_INDEX = 3

-- LuaFormatter off
-- Note.  We do not do any parameters on these calls like min, max etc as the calls are very bespoke and 
--        do not benifit from generic handling.
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "rate_stabilized_yaw", type = "U16", apiVersion = {12, 0, 9}, simResponse = { 250, 0 }},
    { field = "min_stabilized_yaw",  type = "U16", apiVersion = {12, 0, 9}, simResponse = { 30, 251 } },
    { field = "max_stabilized_yaw",  type = "U16", apiVersion = {12, 0, 9}, simResponse = { 226, 4 } },
}

-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    -- mixer input index
    { field = "index", type = "U8" },

    -- mixer input values
    { field = "rate_stabilized_yaw",  type = "U16" },
    { field = "min_stabilized_yaw",   type = "U16" },
    { field = "max_stabilized_yaw",   type = "U16" },
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
    local message = {
        command = MSP_API_CMD_READ,
        apiname = API_NAME,
        payload = { FIXED_INDEX }, 
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
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    local v = {
        index = FIXED_INDEX,
        rate_stabilized_yaw  = (payloadData.rate_stabilized_yaw ~= nil) and payloadData.rate_stabilized_yaw or curRate,
        min_stabilized_yaw   = (payloadData.min_stabilized_yaw  ~= nil) and payloadData.min_stabilized_yaw  or curMin,
        max_stabilized_yaw   = (payloadData.max_stabilized_yaw  ~= nil) and payloadData.max_stabilized_yaw  or curMax,
    }

    local payload = core.buildFullPayload(API_NAME, v, MSP_API_STRUCTURE_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os_clock())
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

    return rfsuite.tasks.msp.mspQueue:add(message)
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
