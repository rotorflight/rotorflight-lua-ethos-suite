--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 -- https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "BOXNAMES"
local MSP_API_CMD_READ = 116
local MSP_MIN_BYTES = 0
local SEMICOLON = 59
local NUL = 0

local mspData = nil
local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local function parseBoxNames(buf)
    local parsed = {}
    local names = {}
    local chars = {}

    local function flushName()
        if #chars == 0 then return end
        names[#names + 1] = table.concat(chars)
        chars = {}
    end

    buf.offset = 1
    while true do
        local b = rfsuite.tasks.msp.mspHelper.readU8(buf)
        if b == nil then break end
        -- Rotorflight/BF commonly use ';', but some stacks/paths can include
        -- NUL separators, so support both.
        if b == SEMICOLON or b == NUL then
            flushName()
        else
            -- Keep only printable ASCII bytes for UI labels.
            if b >= 32 and b <= 126 then
                chars[#chars + 1] = string.char(b)
            end
        end
    end

    flushName()
    parsed.box_names = names
    return {parsed = parsed, buffer = buf}
end

local function read()
    local message = {
        command = MSP_API_CMD_READ,
        apiname = API_NAME,
        processReply = function(self, buf)
            mspData = parseBoxNames(buf)
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
