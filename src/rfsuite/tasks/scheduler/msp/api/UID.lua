--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "UID"
local MSP_API_CMD_READ = 160
local MSP_REBUILD_ON_WRITE = false

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field = "U_ID_0", type = "U32", apiVersion = 12.06, simResponse = {43, 0, 34, 0}, help = "@i18n(api.UID.U_ID_0)@"},
    {field = "U_ID_1", type = "U32", apiVersion = 12.06, simResponse = {9, 81, 51, 52}, help = "@i18n(api.UID.U_ID_1)@"},
    {field = "U_ID_2", type = "U32", apiVersion = 12.06, simResponse = {52, 56, 53, 49}, help = "@i18n(api.UID.U_ID_2)@"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ, MSP_MIN_BYTES, MSP_API_SIMULATOR_RESPONSE = core.prepareStructureData(MSP_API_STRUCTURE_READ_DATA)

local mspData = nil

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

local function errorHandlerStatic(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

local function read()
    local message = {command = MSP_API_CMD_READ, apiname=API_NAME, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData.parsed then return mspData.parsed[fieldName] end
    return nil
end

local function readComplete() return mspData ~= nil and #mspData.buffer >= MSP_MIN_BYTES end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, readValue = readValue, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
