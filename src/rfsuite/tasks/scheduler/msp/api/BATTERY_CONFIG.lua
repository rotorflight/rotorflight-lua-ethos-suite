--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "BATTERY_CONFIG"
local MSP_API_CMD_READ = 32
local MSP_API_CMD_WRITE = 33
local MSP_REBUILD_ON_WRITE = false

local tblBatterySource = {
    [1] = "@i18n(api.BATTERY_CONFIG.source_none)@",
    [2] = "@i18n(api.BATTERY_CONFIG.source_adc)@",
    [3] = "@i18n(api.BATTERY_CONFIG.source_esc)@",
}

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "batteryCapacity", type = "U16", apiVersion = 12.06, simResponse = {136, 19}, min = 0, max = 20000, step = 50, unit = "mAh", default = 0, help = "@i18n(api.BATTERY_CONFIG.batteryCapacity)@"},
    {field = "batteryCellCount", type = "U8", apiVersion = 12.06, simResponse = {6}, min = 0, max = 24, unit = nil, default = 6, help = "@i18n(api.BATTERY_CONFIG.batteryCellCount)@"},
    {field = "voltageMeterSource", type = "U8", apiVersion = 12.06, simResponse = {1}, table = tblBatterySource, tableIdxInc = -1, help = "@i18n(api.BATTERY_CONFIG.voltageMeterSource)@"},
    {field = "currentMeterSource", type = "U8", apiVersion = 12.06, simResponse = {1}, table = tblBatterySource, tableIdxInc = -1, help = "@i18n(api.BATTERY_CONFIG.currentMeterSource)@"},
    {field = "vbatmincellvoltage", type = "U16", apiVersion = 12.06, simResponse = {74, 1}, min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 3.3, help = "@i18n(api.BATTERY_CONFIG.vbatmincellvoltage)@"},
    {field = "vbatmaxcellvoltage", type = "U16", apiVersion = 12.06, simResponse = {164, 1}, min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 4.2, help = "@i18n(api.BATTERY_CONFIG.vbatmaxcellvoltage)@"},
    {field = "vbatfullcellvoltage", type = "U16", apiVersion = 12.06, simResponse = {154, 1}, min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 4.1, help = "@i18n(api.BATTERY_CONFIG.vbatfullcellvoltage)@"},
    {field = "vbatwarningcellvoltage", type = "U16", apiVersion = 12.06, simResponse = {94, 1}, min = 0, decimals = 2, scale = 100, max = 500, unit = "V", default = 3.5, help = "@i18n(api.BATTERY_CONFIG.vbatwarningcellvoltage)@"},
    {field = "lvcPercentage", type = "U8", apiVersion = 12.06, simResponse = {100}, help = "@i18n(api.BATTERY_CONFIG.lvcPercentage)@"},
    {field = "consumptionWarningPercentage", type = "U8", apiVersion = 12.06, simResponse = {30}, min = 0, max = 50, default = 35, unit = "%", help = "@i18n(api.BATTERY_CONFIG.consumptionWarningPercentage)@"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}

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
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    if MSP_API_CMD_WRITE == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_WRITE", "debug")
        return
    end

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os.clock())
    lastWriteUUID = uuid

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function readComplete() return mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
