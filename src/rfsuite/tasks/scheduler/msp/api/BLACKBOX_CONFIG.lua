--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "BLACKBOX_CONFIG"
local MSP_API_CMD_READ = 80
local MSP_API_CMD_WRITE = 81
local MSP_REBUILD_ON_WRITE = true

local offOn = {
    "@i18n(api.MOTOR_CONFIG.tbl_off)@",
    "@i18n(api.MOTOR_CONFIG.tbl_on)@"
}

local blackbox_fields_bitmap = {
    { field = "command",  tableIdxInc = -1, table = offOn }, -- bit 0
    { field = "setpoint", tableIdxInc = -1, table = offOn }, -- bit 1
    { field = "mixer",    tableIdxInc = -1, table = offOn }, -- bit 2
    { field = "pid",      tableIdxInc = -1, table = offOn }, -- bit 3
    { field = "attitude", tableIdxInc = -1, table = offOn }, -- bit 4
    { field = "gyroraw",  tableIdxInc = -1, table = offOn }, -- bit 5
    { field = "gyro",     tableIdxInc = -1, table = offOn }, -- bit 6
    { field = "acc",      tableIdxInc = -1, table = offOn }, -- bit 7
    { field = "mag",      tableIdxInc = -1, table = offOn }, -- bit 8
    { field = "alt",      tableIdxInc = -1, table = offOn }, -- bit 9
    { field = "battery",  tableIdxInc = -1, table = offOn }, -- bit 10
    { field = "rssi",     tableIdxInc = -1, table = offOn }, -- bit 11
    { field = "gps",      tableIdxInc = -1, table = offOn }, -- bit 12
    { field = "rpm",      tableIdxInc = -1, table = offOn }, -- bit 13
    { field = "motors",   tableIdxInc = -1, table = offOn }, -- bit 14
    { field = "servos",   tableIdxInc = -1, table = offOn }, -- bit 15
    { field = "vbec",     tableIdxInc = -1, table = offOn }, -- bit 16
    { field = "vbus",     tableIdxInc = -1, table = offOn }, -- bit 17
    { field = "temps",    tableIdxInc = -1, table = offOn }, -- bit 18
}

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 7}) then
    blackbox_fields_bitmap[#blackbox_fields_bitmap + 1] = { field = "esc", tableIdxInc = -1, table = offOn }   -- bit 19
    blackbox_fields_bitmap[#blackbox_fields_bitmap + 1] = { field = "bec", tableIdxInc = -1, table = offOn }   -- bit 20
    blackbox_fields_bitmap[#blackbox_fields_bitmap + 1] = { field = "esc2", tableIdxInc = -1, table = offOn }  -- bit 21
end

if rfsuite.utils.apiVersionCompare(">=", {12, 0, 9}) then
    blackbox_fields_bitmap[#blackbox_fields_bitmap + 1] = { field = "governor", tableIdxInc = -1, table = offOn } -- bit 22
end

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    -- Sim values aligned to observed payload:
    -- READ [80]{1,1,1,8,0,127,238,7,0,0,0,0,5}
    { field = "blackbox_supported", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "device", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "mode", type = "U8", apiVersion = {12, 0, 6}, simResponse = {1} },
    { field = "denom", type = "U16", apiVersion = {12, 0, 6}, simResponse = {8,0}, unit = "1/x" },
    { field = "fields", type = "U32", apiVersion = {12, 0, 6}, simResponse = {127,238,7,0}, bitmap = blackbox_fields_bitmap },
    { field = "initialEraseFreeSpaceKiB", type = "U16", apiVersion = {12, 0, 6}, simResponse = {0,0}, mandatory = false, unit = "KiB" },
    { field = "rollingErase", type = "U8", apiVersion = {12, 0, 6}, simResponse = {0}, mandatory = false },
    { field = "gracePeriod", type = "U8", apiVersion = {12, 0, 6}, simResponse = {5}, mandatory = false, unit = "s" },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

-- LuaFormatter off
local MSP_API_STRUCTURE_WRITE = {
    { field = "device", type = "U8" },
    { field = "mode", type = "U8" },
    { field = "denom", type = "U16" },
    { field = "fields", type = "U32" },
    { field = "initialEraseFreeSpaceKiB", type = "U16", mandatory = false },
    { field = "rollingErase", type = "U8", mandatory = false },
    { field = "gracePeriod", type = "U8", mandatory = false },
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
