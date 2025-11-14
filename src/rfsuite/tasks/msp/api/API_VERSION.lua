--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "API_VERSION"
local MSP_API_CMD_READ = 1

local MSP_API_SIMULATOR_RESPONSE = rfsuite.utils.splitVersionStringToNumbers(rfsuite.config.supportedMspApiVersion[rfsuite.preferences.developer.apiversion])

-- LuaFormatter off
local MSP_API_STRUCTURE_READ = {
    { field = "version_command", type = "U8", help = "@i18n(api.API_VERSION.version_command)@" },
    { field = "version_major",   type = "U8", help = "@i18n(api.API_VERSION.version_major)@" },
    { field = "version_minor",   type = "U8", help = "@i18n(api.API_VERSION.version_minor)@" },
}
-- LuaFormatter on

local MSP_MIN_BYTES = #MSP_API_STRUCTURE_READ

local mspData = nil

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

local function read()
    if MSP_API_CMD_READ == nil then
        rfsuite.utils.log("No value set for MSP_API_CMD_READ", "debug")
        return
    end

    local message = {command = MSP_API_CMD_READ, structure = MSP_API_STRUCTURE_READ, minBytes = MSP_MIN_BYTES, processReply = processReplyStaticRead, errorHandler = errorHandlerStatic, simulatorResponse = MSP_API_SIMULATOR_RESPONSE, uuid = MSP_API_UUID, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler, mspData = nil}
    rfsuite.tasks.msp.mspQueue:add(message)
end

local function data() return mspData end

local function readComplete()
    if mspData ~= nil and #mspData['buffer'] >= MSP_MIN_BYTES then return true end
    return false
end

local function readVersion() if mspData then return mspData['parsed'].version_major + mspData['parsed'].version_minor / 100 end end

local function readValue(fieldName)
    if mspData and mspData['parsed'][fieldName] ~= nil then return mspData['parsed'][fieldName] end
    return nil
end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

return {data = data, read = read, readComplete = readComplete, readVersion = readVersion, readValue = readValue, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, setUUID = setUUID, setTimeout = setTimeout}
