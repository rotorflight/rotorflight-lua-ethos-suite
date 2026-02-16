--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "BOARD_INFO"
local MSP_API_CMD_READ = 4
local MSP_API_CMD_WRITE = 248
local MSP_REBUILD_ON_WRITE = true
local TARGET_NAME_MAX = 32
local BOARD_NAME_MAX = 20
local BOARD_DESIGN_MAX = 12
local MANUFACTURER_ID_MAX = 4

local MSP_API_STRUCTURE_READ_DATA = {
    { field = "board_identifier_1", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {82}, mandatory = false },
    { field = "board_identifier_2", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {70}, mandatory = false },
    { field = "board_identifier_3", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {76}, mandatory = false },
    { field = "board_identifier_4", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {84}, mandatory = false },
    { field = "hardware_revision",  type = "U16", apiVersion = {12, 0, 6}, simResponse = {0, 0}, mandatory = false },
    { field = "fc_type",            type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "target_capabilities",type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "target_name_length", type = "U8",  apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
}
for i = 1, TARGET_NAME_MAX do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "target_name_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "board_name_length", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
for i = 1, BOARD_NAME_MAX do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "board_name_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "board_design_length", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
for i = 1, BOARD_DESIGN_MAX do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "board_design_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "manufacturer_id_length", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
for i = 1, MANUFACTURER_ID_MAX do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "manufacturer_id_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
for i = 1, 32 do
    MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "signature_" .. i, type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
end
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "mcu_type_id", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "configuration_state", type = "U8", apiVersion = {12, 42}, simResponse = {0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "gyro_sample_rate_hz", type = "U16", apiVersion = {12, 43}, simResponse = {0, 0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "configuration_problems", type = "U32", apiVersion = {12, 43}, simResponse = {0, 0, 0, 0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "spi_device_count", type = "U8", apiVersion = {12, 44}, simResponse = {0}, mandatory = false }
MSP_API_STRUCTURE_READ_DATA[#MSP_API_STRUCTURE_READ_DATA + 1] = { field = "i2c_device_count", type = "U8", apiVersion = {12, 44}, simResponse = {0}, mandatory = false }

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = {
    { field = "board_name_length", type = "U8" },
}
for i = 1, BOARD_NAME_MAX do
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "board_name_" .. i, type = "U8" }
end
MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "board_design_length", type = "U8" }
for i = 1, BOARD_DESIGN_MAX do
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "board_design_" .. i, type = "U8" }
end
MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "manufacturer_id_length", type = "U8" }
for i = 1, MANUFACTURER_ID_MAX do
    MSP_API_STRUCTURE_WRITE[#MSP_API_STRUCTURE_WRITE + 1] = { field = "manufacturer_id_" .. i, type = "U8" }
end

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
