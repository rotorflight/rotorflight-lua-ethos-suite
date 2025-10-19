--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "PID_TUNING"
local MSP_API_CMD_READ = 112
local MSP_API_CMD_WRITE = 202
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "pid_0_P", type = "U16", apiVersion = 12.06, simResponse = {50, 0}, min = 0, max = 1000, default = 50, help = "@i18n(api.PID_TUNING.pid_0_P)@"},
    {field = "pid_0_I", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 1000, default = 100, help = "@i18n(api.PID_TUNING.pid_0_I)@"},
    {field = "pid_0_D", type = "U16", apiVersion = 12.06, simResponse = {20, 0}, min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_0_D)@"},
    {field = "pid_0_F", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 1000, default = 100, help = "@i18n(api.PID_TUNING.pid_0_F)@"},

    {field = "pid_1_P", type = "U16", apiVersion = 12.06, simResponse = {50, 0}, min = 0, max = 1000, default = 50, help = "@i18n(api.PID_TUNING.pid_1_P)@"},
    {field = "pid_1_I", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 1000, default = 100, help = "@i18n(api.PID_TUNING.pid_1_I)@"},
    {field = "pid_1_D", type = "U16", apiVersion = 12.06, simResponse = {50, 0}, min = 0, max = 1000, default = 40, help = "@i18n(api.PID_TUNING.pid_1_D)@"},
    {field = "pid_1_F", type = "U16", apiVersion = 12.06, simResponse = {100, 0}, min = 0, max = 1000, default = 100, help = "@i18n(api.PID_TUNING.pid_1_F)@"},

    {field = "pid_2_P", type = "U16", apiVersion = 12.06, simResponse = {80, 0}, min = 0, max = 1000, default = 80, help = "@i18n(api.PID_TUNING.pid_2_P)@"},
    {field = "pid_2_I", type = "U16", apiVersion = 12.06, simResponse = {120, 0}, min = 0, max = 1000, default = 120, help = "@i18n(api.PID_TUNING.pid_2_I)@"},
    {field = "pid_2_D", type = "U16", apiVersion = 12.06, simResponse = {40, 0}, min = 0, max = 1000, default = 10, help = "@i18n(api.PID_TUNING.pid_2_D)@"},
    {field = "pid_2_F", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_2_F)@"},

    {field = "pid_0_B", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_0_B)@"},
    {field = "pid_1_B", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_1_B)@"},
    {field = "pid_2_B", type = "U16", apiVersion = 12.06, simResponse = {0, 0}, min = 0, max = 1000, default = 0, help = "@i18n(api.PID_TUNING.pid_2_B)@"},
 
    {field = "pid_0_O", type = "U16", apiVersion = 12.06, simResponse = {45, 0}, min = 0, max = 1000, default = 45, help = "@i18n(api.PID_TUNING.pid_0_O)@"},
    {field = "pid_1_O", type = "U16", apiVersion = 12.06, simResponse = {45, 0}, min = 0, max = 1000, default = 45, help = "@i18n(api.PID_TUNING.pid_1_O)@"}
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
