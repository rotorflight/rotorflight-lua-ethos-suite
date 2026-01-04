--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "STATUS"
local MSP_API_CMD_READ = 101
local MSP_API_CMD_WRITE = nil
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "task_delta_time_pid", type = "U16", apiVersion = 12.06, simResponse = {252, 1}, help = "@i18n(api.STATUS.task_delta_time_pid)@"},
    {field = "task_delta_time_gyro", type = "U16", apiVersion = 12.06, simResponse = {127, 0}, help = "@i18n(api.STATUS.task_delta_time_gyro)@"},
    {field = "sensor_status", type = "U16", apiVersion = 12.06, simResponse = {35, 0}, help = "@i18n(api.STATUS.sensor_status)@"},
    {field = "flight_mode_flags", type = "U32", apiVersion = 12.06, simResponse = {0, 0, 0, 0}, help = "@i18n(api.STATUS.flight_mode_flags)@"},
    {field = "profile_number", type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.STATUS.profile_number)@"},
    {field = "max_real_time_load", type = "U16", apiVersion = 12.06, simResponse = {122, 1}, help = "@i18n(api.STATUS.max_real_time_load)@"},
    {field = "average_cpu_load", type = "U16", apiVersion = 12.06, simResponse = {182, 0}, help = "@i18n(api.STATUS.average_cpu_load)@"},
    {field = "extra_flight_mode_flags_count", type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.STATUS.extra_flight_mode_flags_count)@"},
    {field = "arming_disable_flags_count", type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.STATUS.arming_disable_flags_count)@"},
    {field = "arming_disable_flags", type = "U32", apiVersion = 12.06, simResponse = {0, 0, 0, 0}, help = "@i18n(api.STATUS.arming_disable_flags)@"},
    {field = "reboot_required", type = "U8", apiVersion = 12.06, simResponse = {2}, help = "@i18n(api.STATUS.reboot_required)@"},
    {field = "configuration_state", type = "U8", apiVersion = 12.06, simResponse = {0}, help = "@i18n(api.STATUS.configuration_state)@"},
    {field = "current_pid_profile_index", type = "U8", apiVersion = 12.06, simResponse = {5}, table = {"1", "2", "3", "4", "5", "6"}, tableIdxInc = -1, help = "@i18n(api.STATUS.current_pid_profile_index)@"},
    {field = "pid_profile_count", type = "U8", apiVersion = 12.06, simResponse = {6}, help = "@i18n(api.STATUS.pid_profile_count)@"},
    {field = "current_control_rate_profile_index", type = "U8", apiVersion = 12.06, simResponse = {1}, table = {"1", "2", "3", "4", "5", "6"}, tableIdxInc = -1, help = "@i18n(api.STATUS.current_control_rate_profile_index)@"},
    {field = "control_rate_profile_count", type = "U8", apiVersion = 12.06, simResponse = {4}, help = "@i18n(api.STATUS.control_rate_profile_count)@"},
    {field = "motor_count", type = "U8", apiVersion = 12.06, simResponse = {1}, help = "@i18n(api.STATUS.motor_count)@"},
    {field = "servo_count", type = "U8", apiVersion = 12.06, simResponse = {4}, help = "@i18n(api.STATUS.servo_count)@"},
    {field = "gyro_detection_flags", type = "U8", apiVersion = 12.06, simResponse = {1}, help = "@i18n(api.STATUS.gyro_detection_flags)@"}
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

return {read = read, write = write, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
