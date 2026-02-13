--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "VTXTABLE_BAND"
local MSP_API_CMD_READ = 137
local MSP_API_CMD_WRITE = 227
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "band",           type = "U8",  apiVersion = 12.06, simResponse = {1}, mandatory = false },
    { field = "name_length",    type = "U8",  apiVersion = 12.06, simResponse = {8}, mandatory = false },
    { field = "name_1",         type = "U8",  apiVersion = 12.06, simResponse = {65}, mandatory = false },
    { field = "name_2",         type = "U8",  apiVersion = 12.06, simResponse = {66}, mandatory = false },
    { field = "name_3",         type = "U8",  apiVersion = 12.06, simResponse = {67}, mandatory = false },
    { field = "name_4",         type = "U8",  apiVersion = 12.06, simResponse = {68}, mandatory = false },
    { field = "name_5",         type = "U8",  apiVersion = 12.06, simResponse = {69}, mandatory = false },
    { field = "name_6",         type = "U8",  apiVersion = 12.06, simResponse = {70}, mandatory = false },
    { field = "name_7",         type = "U8",  apiVersion = 12.06, simResponse = {71}, mandatory = false },
    { field = "name_8",         type = "U8",  apiVersion = 12.06, simResponse = {72}, mandatory = false },
    { field = "band_letter",    type = "U8",  apiVersion = 12.06, simResponse = {65}, mandatory = false },
    { field = "is_factory_band",type = "U8",  apiVersion = 12.06, simResponse = {1}, mandatory = false },
    { field = "channel_count",  type = "U8",  apiVersion = 12.06, simResponse = {8}, mandatory = false },
    { field = "freq_1",         type = "U16", apiVersion = 12.06, simResponse = {100, 22}, mandatory = false },
    { field = "freq_2",         type = "U16", apiVersion = 12.06, simResponse = {120, 22}, mandatory = false },
    { field = "freq_3",         type = "U16", apiVersion = 12.06, simResponse = {140, 22}, mandatory = false },
    { field = "freq_4",         type = "U16", apiVersion = 12.06, simResponse = {160, 22}, mandatory = false },
    { field = "freq_5",         type = "U16", apiVersion = 12.06, simResponse = {180, 22}, mandatory = false },
    { field = "freq_6",         type = "U16", apiVersion = 12.06, simResponse = {200, 22}, mandatory = false },
    { field = "freq_7",         type = "U16", apiVersion = 12.06, simResponse = {220, 22}, mandatory = false },
    { field = "freq_8",         type = "U16", apiVersion = 12.06, simResponse = {240, 22}, mandatory = false },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    { field = "band",            type = "U8"  },
    { field = "name_length",     type = "U8"  },
    { field = "name_1",          type = "U8"  },
    { field = "name_2",          type = "U8"  },
    { field = "name_3",          type = "U8"  },
    { field = "name_4",          type = "U8"  },
    { field = "name_5",          type = "U8"  },
    { field = "name_6",          type = "U8"  },
    { field = "name_7",          type = "U8"  },
    { field = "name_8",          type = "U8"  },
    { field = "band_letter",     type = "U8"  },
    { field = "is_factory_band", type = "U8"  },
    { field = "channel_count",   type = "U8"  },
    { field = "freq_1",          type = "U16" },
    { field = "freq_2",          type = "U16" },
    { field = "freq_3",          type = "U16" },
    { field = "freq_4",          type = "U16" },
    { field = "freq_5",          type = "U16" },
    { field = "freq_6",          type = "U16" },
    { field = "freq_7",          type = "U16" },
    { field = "freq_8",          type = "U16" },
}
-- LuaFormatter on

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

local function read(band)
    if MSP_API_CMD_READ == nil then return false, "read_not_supported" end
    local readBand = tonumber(band)
    if readBand == nil then readBand = tonumber(payloadData.band) end
    if readBand == nil then readBand = 1 end
    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, payload = {readBand}, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
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
