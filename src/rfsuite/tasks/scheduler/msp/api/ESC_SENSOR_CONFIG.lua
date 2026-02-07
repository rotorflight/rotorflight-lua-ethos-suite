--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "ESC_SENSOR_CONFIG"
local MSP_API_CMD_READ = 123
local MSP_API_CMD_WRITE = 216
local MSP_REBUILD_ON_WRITE = false

local escTypes = {"NONE", "BLHELI32", "HOBBYWING V4", "HOBBYWING V5", "SCORPION", "KONTRONIK", "OMP", "ZTW", "APD", "OPENYGE", "FLYROTOR", "GRAUPNER", "XDFLY", "RECORD"}
local onOff = {"@i18n(api.ESC_SENSOR_CONFIG.tbl_off)@", "@i18n(api.ESC_SENSOR_CONFIG.tbl_on)@"}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    { field = "protocol", type = "U8", apiVersion = 12.06, simResponse = {0}, table = escTypes, tableIdxInc = -1, help = "@i18n(api.ESC_SENSOR_CONFIG.protocol)@" },
    { field = "half_duplex", type = "U8", apiVersion = 12.06, simResponse = {0}, default = 0, min = 1, max = 2, table = onOff, tableIdxInc = -1, help = "@i18n(api.ESC_SENSOR_CONFIG.half_duplex)@" },
    { field = "update_hz", type = "U16", apiVersion = 12.06, simResponse = {200, 0}, default = 200, min = 10, max = 500, unit = "Hz", help = "@i18n(api.ESC_SENSOR_CONFIG.update_hz)@" },
    { field = "current_offset", type = "U16", apiVersion = 12.06, simResponse = {0, 15}, min = 0, max = 1000, default = 0, help = "@i18n(api.ESC_SENSOR_CONFIG.current_offset)@" },
    { field = "hw4_current_offset", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 1000, default = 0, help = "@i18n(api.ESC_SENSOR_CONFIG.hw4_current_offset)@" },
    { field = "hw4_current_gain", type = "U8", apiVersion = 12.06, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.ESC_SENSOR_CONFIG.hw4_current_gain)@" },
    { field = "hw4_voltage_gain", type = "U8", apiVersion = 12.06, simResponse = {30}, min = 0, max = 250, default = 30, help = "@i18n(api.ESC_SENSOR_CONFIG.hw4_voltage_gain)@" },
    { field = "pin_swap", type = "U8", apiVersion = 12.07, simResponse = {0}, table = onOff, tableIdxInc = -1, help = "@i18n(api.ESC_SENSOR_CONFIG.pin_swap)@" },
    { field = "voltage_correction", mandatory = false, type = "S8", apiVersion = 12.08, simResponse = {0}, unit = "%", default = 1, min = -99, max = 125, help = "@i18n(api.ESC_SENSOR_CONFIG.voltage_correction)@" },
    { field = "current_correction", mandatory = false, type = "S8", apiVersion = 12.08, simResponse = {0}, unit = "%", default = 1, min = -99, max = 125, help = "@i18n(api.ESC_SENSOR_CONFIG.current_correction)@" },
    { field = "consumption_correction", mandatory = false, type = "S8", apiVersion = 12.08, simResponse = {0}, unit = "%", default = 1, min = -99, max = 125, help = "@i18n(api.ESC_SENSOR_CONFIG.consumption_correction)@" },
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

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
    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os_clock())
    lastWriteUUID = uuid

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    rfsuite.tasks.msp.mspQueue:add(message)
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
