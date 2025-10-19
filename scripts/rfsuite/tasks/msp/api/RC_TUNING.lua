--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "RC_TUNING"
local MSP_API_CMD_READ = 111
local MSP_API_CMD_WRITE = 204
local MSP_REBUILD_ON_WRITE = true

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rates_type", type = "U8", apiVersion = 12.06, simResponse = {4}, min = 0, max = 6, default = 4, tableIdxInc = -1, table = {"NONE", "BETAFLIGHT", "RACEFLIGHT", "KISS", "ACTUAL", "QUICK"}, help = "@i18n(api.RC_TUNING.rates_type)@"},
    {field = "rcRates_1", type = "U8", apiVersion = 12.06, simResponse = {18}, help = "@i18n(api.RC_TUNING.rcRates_1)@"},
    {field = "rcExpo_1", type = "U8", apiVersion = 12.06, simResponse = {25}, help = "@i18n(api.RC_TUNING.rcExpo_1)@"},
    {field = "rates_1", type = "U8", apiVersion = 12.06, simResponse = {32}, help = "@i18n(api.RC_TUNING.rates_1)@"},
    {field = "response_time_1", type = "U8", apiVersion = 12.06, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_1)@"},
    {field = "accel_limit_1", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_1)@"},
    {field = "rcRates_2", type = "U8", apiVersion = 12.06, simResponse = {18}, help = "@i18n(api.RC_TUNING.rcRates_2)@"},
    {field = "rcExpo_2", type = "U8", apiVersion = 12.06, simResponse = {25}, help = "@i18n(api.RC_TUNING.rcExpo_2)@"},
    {field = "rates_2", type = "U8", apiVersion = 12.06, simResponse = {32}, help = "@i18n(api.RC_TUNING.rates_2)@"},
    {field = "response_time_2", type = "U8", apiVersion = 12.06, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_2)@"},
    {field = "accel_limit_2", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_2)@"},
    {field = "rcRates_3", type = "U8", apiVersion = 12.06, simResponse = {32}, help = "@i18n(api.RC_TUNING.rcRates_3)@"},
    {field = "rcExpo_3", type = "U8", apiVersion = 12.06, simResponse = {50}, help = "@i18n(api.RC_TUNING.rcExpo_3)@"},
    {field = "rates_3", type = "U8", apiVersion = 12.06, simResponse = {45}, help = "@i18n(api.RC_TUNING.rates_3)@"},
    {field = "response_time_3", type = "U8", apiVersion = 12.06, simResponse = {10}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_3)@"},
    {field = "accel_limit_3", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_3)@"},
    {field = "rcRates_4", type = "U8", apiVersion = 12.06, simResponse = {56}, help = "@i18n(api.RC_TUNING.rcRates_4)@"},
    {field = "rcExpo_4", type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.RC_TUNING.rcExpo_4)@"},
    {field = "rates_4", type = "U8", apiVersion = 12.06, simResponse = {56}, help = "@i18n(api.RC_TUNING.rates_4)@"},
    {field = "response_time_4", type = "U8", apiVersion = 12.06, simResponse = {20}, min = 0, max = 250, unit = "ms", help = "@i18n(api.RC_TUNING.response_time_4)@"},
    {field = "accel_limit_4", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 50000, unit = "°/s", step = 10, mult = 10, help = "@i18n(api.RC_TUNING.accel_limit_4)@"},
    {field = "setpoint_boost_gain_1", type = "U8", apiVersion = 12.08, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_1)@"},
    {field = "setpoint_boost_cutoff_1", type = "U8", apiVersion = 12.08, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_1)@"},
    {field = "setpoint_boost_gain_2", type = "U8", apiVersion = 12.08, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_2)@"},
    {field = "setpoint_boost_cutoff_2", type = "U8", apiVersion = 12.08, simResponse = {90}, min = 0, max = 250, unit = "Hz", default = 90, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_2)@"},
    {field = "setpoint_boost_gain_3", type = "U8", apiVersion = 12.08, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_3)@"},
    {field = "setpoint_boost_cutoff_3", type = "U8", apiVersion = 12.08, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_3)@"},
    {field = "setpoint_boost_gain_4", type = "U8", apiVersion = 12.08, simResponse = {0}, min = 0, max = 250, default = 0, help = "@i18n(api.RC_TUNING.setpoint_boost_gain_4)@"},
    {field = "setpoint_boost_cutoff_4", type = "U8", apiVersion = 12.08, simResponse = {15}, min = 0, max = 250, unit = "Hz", default = 15, help = "@i18n(api.RC_TUNING.setpoint_boost_cutoff_4)@"},
    {field = "yaw_dynamic_ceiling_gain", type = "U8", apiVersion = 12.08, simResponse = {30}, default = 30, min = 0, max = 250, help = "@i18n(api.RC_TUNING.yaw_dynamic_ceiling_gain)@"},
    {field = "yaw_dynamic_deadband_gain", type = "U8", apiVersion = 12.08, simResponse = {30}, default = 30, min = 0, max = 250, help = "@i18n(api.RC_TUNING.yaw_dynamic_deadband_gain)@"},
    {field = "yaw_dynamic_deadband_filter", type = "U8", apiVersion = 12.08, simResponse = {60}, scale = 10, decimals = 1, default = 60, min = 0, max = 250, unit = "Hz", help = "@i18n(api.RC_TUNING.yaw_dynamic_deadband_filter)@"}
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

    local message = {command = MSP_API_CMD_READ, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
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

    local message = {command = MSP_API_CMD_WRITE, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

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

return {read = read, write = write, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
