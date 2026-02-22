--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "VOLTAGE_METER_CONFIG"
local MSP_API_CMD_READ = 56
local MSP_API_CMD_WRITE = 57
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "meter_count",   type = "U8",  apiVersion = {12, 0, 6}, simResponse = {4} },
    { field = "frame_length_1", type = "U8", apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "meter_id_1",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0} },
    { field = "meter_type_1",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "scale_1",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "divider_1",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {1, 0} },
    { field = "divmul_1",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "frame_length_2", type = "U8", apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "meter_id_2",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "meter_type_2",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "scale_2",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "divider_2",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {1, 0} },
    { field = "divmul_2",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "frame_length_3", type = "U8", apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "meter_id_3",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {2} },
    { field = "meter_type_3",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "scale_3",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "divider_3",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {1, 0} },
    { field = "divmul_3",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "frame_length_4", type = "U8", apiVersion = {12, 0, 6}, simResponse = {7} },
    { field = "meter_id_4",    type = "U8",  apiVersion = {12, 0, 6}, simResponse = {3} },
    { field = "meter_type_4",  type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "scale_4",       type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0} },
    { field = "divider_4",     type = "U16", apiVersion = {12, 0, 6}, simResponse = {1, 0} },
    { field = "divmul_4",      type = "U8",  apiVersion = {12, 0, 6}, simResponse = {1} },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "meter_id", type = "U8"  },
    { field = "scale",    type = "U16" },
    { field = "divider",  type = "U16" },
    { field = "divmul",   type = "U8"  },
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
