--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "BOXIDS"
local MSP_API_CMD_READ = 119
local MSP_MIN_BYTES = 0

local mspData = nil
local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local function parseBoxIds(buf)
    local parsed = {}
    local ids = {}
    buf.offset = 1
    while true do
        local id = rfsuite.tasks.msp.mspHelper.readU8(buf)
        if id == nil then break end
        ids[#ids + 1] = id
    end
    parsed.box_ids = ids
    return {parsed = parsed, buffer = buf}
end

local function read()
    local message = {
        command = MSP_API_CMD_READ,
        apiname = API_NAME,
        processReply = function(self, buf)
            mspData = parseBoxIds(buf)
            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then completeHandler(self, buf) end
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = {},
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT
    }

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
local function setRebuildOnWrite(_) end

return {
    read = read,
    setRebuildOnWrite = setRebuildOnWrite,
    readComplete = readComplete,
    readValue = readValue,
    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler,
    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout
}
