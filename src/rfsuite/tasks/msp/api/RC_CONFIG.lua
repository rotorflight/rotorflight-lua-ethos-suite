--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "RC_CONFIG"
local MSP_API_CMD_READ = 66
local MSP_API_CMD_WRITE = 67
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "rc_center", type = "U16", apiVersion = 12.06, simResponse = {220, 5}, min = 1400, max = 1600, default = 1500, unit = "us", help = "@i18n(api.RC_CONFIG.rc_center)@"},
    {field = "rc_deflection", type = "U16", apiVersion = 12.06, simResponse = {254, 1}, min = 200, max = 700, default = 510, unit = "us", help = "@i18n(api.RC_CONFIG.rc_deflection)@"},
    {field = "rc_arm_throttle", type = "U16", apiVersion = 12.06, simResponse = {232, 3}, min = 850, max = 1500, default = 1050, unit = "us", help = "@i18n(api.RC_CONFIG.rc_arm_throttle)@"},
    {field = "rc_min_throttle", type = "U16", apiVersion = 12.06, simResponse = {242, 3}, min = 860, max = 1500, default = 1100, unit = "us", help = "@i18n(api.RC_CONFIG.rc_min_throttle)@"},
    {field = "rc_max_throttle", type = "U16", apiVersion = 12.06, simResponse = {208, 7}, min = 1510, max = 2150, default = 1900, unit = "us", help = "@i18n(api.RC_CONFIG.rc_max_throttle)@"},
    {field = "rc_deadband", type = "U8", apiVersion = 12.06, simResponse = {4}, min = 0, max = 100, default = 2, unit = "us", help = "@i18n(api.RC_CONFIG.rc_deadband)@"},
    {field = "rc_yaw_deadband", type = "U8", apiVersion = 12.06, simResponse = {4}, min = 0, max = 100, default = 2, unit = "us", help = "@i18n(api.RC_CONFIG.rc_yaw_deadband)@"},
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
