--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "FILTER_CONFIG"
local MSP_API_CMD_READ = 92
local MSP_API_CMD_WRITE = 93
local MSP_REBUILD_ON_WRITE = false

local gyroFilterType = {[0] = "@i18n(api.FILTER_CONFIG.tbl_none)@", [1] = "@i18n(api.FILTER_CONFIG.tbl_1st)@", [2] = "@i18n(api.FILTER_CONFIG.tbl_2nd)@"}
local rpmPreset = {"@i18n(api.FILTER_CONFIG.tbl_custom)@", "@i18n(api.FILTER_CONFIG.tbl_low)@", "@i18n(api.FILTER_CONFIG.tbl_medium)@", "@i18n(api.FILTER_CONFIG.tbl_high)@"}

local MSP_API_STRUCTURE_READ_DATA = {
    {field = "gyro_hardware_lpf", type = "U8", apiVersion = 12.07, simResponse = {0}, help = "@i18n(api.FILTER_CONFIG.gyro_hardware_lpf)@"},
    {field = "gyro_lpf1_type", type = "U8", apiVersion = 12.07, simResponse = {1}, min = 0, max = #gyroFilterType, table = gyroFilterType, help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_type)@"},
    {field = "gyro_lpf1_static_hz", type = "U16", apiVersion = 12.07, simResponse = {100, 0}, min = 0, max = 4000, unit = "Hz", default = 100, help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_static_hz)@"},
    {field = "gyro_lpf2_type", type = "U8", apiVersion = 12.07, simResponse = {0}, min = 0, max = #gyroFilterType, table = gyroFilterType, help = "@i18n(api.FILTER_CONFIG.gyro_lpf2_type)@"},
    {field = "gyro_lpf2_static_hz", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_lpf2_static_hz)@"},
    {field = "gyro_soft_notch_hz_1", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_hz_1)@"},
    {field = "gyro_soft_notch_cutoff_1", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_cutoff_1)@"},
    {field = "gyro_soft_notch_hz_2", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_hz_2)@"},
    {field = "gyro_soft_notch_cutoff_2", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 4000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_soft_notch_cutoff_2)@"},
    {field = "gyro_lpf1_dyn_min_hz", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 0, max = 1000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_dyn_min_hz)@"},
    {field = "gyro_lpf1_dyn_max_hz", type = "U16", apiVersion = 12.07, simResponse = {25, 0}, min = 0, max = 1000, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.gyro_lpf1_dyn_max_hz)@"},
    {field = "dyn_notch_count", type = "U8", apiVersion = 12.07, simResponse = {0}, min = 0, max = 8, help = "@i18n(api.FILTER_CONFIG.dyn_notch_count)@"},
    {field = "dyn_notch_q", type = "U8", apiVersion = 12.07, simResponse = {100}, min = 0, max = 100, decimals = 1, scale = 10, help = "@i18n(api.FILTER_CONFIG.dyn_notch_q)@"},
    {field = "dyn_notch_min_hz", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 10, max = 200, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.dyn_notch_min_hz)@"},
    {field = "dyn_notch_max_hz", type = "U16", apiVersion = 12.07, simResponse = {0, 0}, min = 100, max = 500, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.dyn_notch_max_hz)@"},
    {field = "rpm_preset", type = "U8", apiVersion = 12.08, simResponse = {1}, table = rpmPreset, tableIdxInc = -1, help = "@i18n(api.FILTER_CONFIG.rpm_preset)@"},
    {field = "rpm_min_hz", type = "U8", apiVersion = 12.08, simResponse = {20}, min = 1, max = 100, unit = "Hz", help = "@i18n(api.FILTER_CONFIG.rpm_min_hz)@"}
}

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

    local message = {
        command = MSP_API_CMD_READ,
        structure = MSP_API_STRUCTURE_READ,
        minBytes = MSP_MIN_BYTES,
        processReply = processReplyStaticRead,
        errorHandler = errorHandlerStatic,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
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

    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os.clock())
    lastWriteUUID = uuid

    local message = {
        command = MSP_API_CMD_WRITE,
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
    setTimeout = setTimeout
}
