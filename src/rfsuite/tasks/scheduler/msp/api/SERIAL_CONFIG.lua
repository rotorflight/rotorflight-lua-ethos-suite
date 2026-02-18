--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "SERIAL_CONFIG"
local MSP_API_CMD_READ = 54
local MSP_API_CMD_WRITE = 55
local MSP_REBUILD_ON_WRITE = true
local MAX_SERIAL_PORTS = 12

local MSP_API_STRUCTURE_READ_DATA = {}
for i = 1, MAX_SERIAL_PORTS do
    local mandatory = (i == 1)
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "port_" .. i .. "_identifier",        type = "U8",  apiVersion = {12, 0, 6}, simResponse = {i - 1}, mandatory = mandatory }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "port_" .. i .. "_function_mask",     type = "U32", apiVersion = {12, 0, 6}, simResponse = {0, 0, 0, 0}, mandatory = mandatory }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "port_" .. i .. "_msp_baud_index",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = mandatory }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "port_" .. i .. "_gps_baud_index",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = mandatory }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "port_" .. i .. "_telem_baud_index",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = mandatory }
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "port_" .. i .. "_blackbox_baud_index", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = mandatory }
end

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "identifier",           type = "U8"  },
    { field = "function_mask",        type = "U32" },
    { field = "msp_baud_index",       type = "U8"  },
    { field = "gps_baud_index",       type = "U8"  },
    { field = "telem_baud_index",     type = "U8"  },
    { field = "blackbox_baud_index",  type = "U8"  },
}

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local os_clock = os.clock
local tostring = tostring

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

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
    if MSP_API_CMD_READ == nil then return false, "read_not_supported" end
    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then return false, "write_not_supported" end
    if suppliedPayload == nil and #MSP_API_STRUCTURE_WRITE == 0 then
        return false, "write_not_implemented"
    end
    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)
    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os_clock())
    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}
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
