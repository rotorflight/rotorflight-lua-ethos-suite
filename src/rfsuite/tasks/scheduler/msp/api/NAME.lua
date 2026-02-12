--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api_core.lua"))()

local API_NAME = "NAME"
local MSP_API_CMD_READ = 10
local MSP_API_CMD_WRITE = nil
local MSP_REBUILD_ON_WRITE = false
local MSP_MIN_BYTES = 0

-- LuaFormatter off
local MSP_API_STRUCTURE_READ_DATA = {
    {field="name",mandatory=false,type="U8",apiVersion=12.06,simResponse={80,105,108,111,116},help="@i18n(api.NAME.name)@"}
}
-- LuaFormatter on

local MSP_API_STRUCTURE_READ = core.filterByApiVersion(MSP_API_STRUCTURE_READ_DATA)

local MSP_API_STRUCTURE_WRITE = MSP_API_STRUCTURE_READ

local MSP_API_SIMULATOR_RESPONSE = core.buildSimResponse(MSP_API_STRUCTURE_READ)

local mspData = nil
local mspWriteComplete = false
local payloadData = {}
local defaultData = {}
local os_clock = os.clock
local tostring = tostring
local log = rfsuite.utils.log

local handlers = core.createHandlers()

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

local function parseMSPData(buf)
    local parsedData = {}

    local name = ""
    local offset = 1

    while offset <= #buf do
        local char = rfsuite.tasks.msp.mspHelper.readU8(buf, offset)
        if char == 0 then break end
        if char then
            name = name .. string.char(char)
        end    
        offset = offset + 1
    end

    if #buf == 0 then name = "" end

    parsedData["name"] = name

    local data = {}
    data['parsed'] = parsedData
    data['buffer'] = buf

    return data
end

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
    local message = {
        command = MSP_API_CMD_READ,
        apiname = API_NAME,
        processReply = function(self, buf)

            mspData = parseMSPData(buf, MSP_API_STRUCTURE)
            if #buf >= 0 then
                local completeHandler = handlers.getCompleteHandler()
                if completeHandler then completeHandler(self, buf) end
            end
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = MSP_API_SIMULATOR_RESPONSE,
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT
    }

    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function write(suppliedPayload)
    local payload = suppliedPayload or core.buildWritePayload(API_NAME, payloadData, MSP_API_STRUCTURE_WRITE, MSP_REBUILD_ON_WRITE)

    local uuid = MSP_API_UUID or rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid() or tostring(os_clock())
    lastWriteUUID = uuid

    local message = {command = MSP_API_CMD_WRITE, apiname = API_NAME, payload = payload, processReply = processReplyStaticWrite, errorHandler = errorHandlerStatic, simulatorResponse = {}, uuid = uuid, timeout = MSP_API_MSG_TIMEOUT, getCompleteHandler = handlers.getCompleteHandler, getErrorHandler = handlers.getErrorHandler}

    return rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue(fieldName)
    if mspData and mspData.parsed then return mspData.parsed[fieldName] end
    return nil
end

local function setValue(fieldName, value) payloadData[fieldName] = value end

local function readComplete() return mspData ~= nil and #mspData.buffer >= MSP_MIN_BYTES end

local function writeComplete() return mspWriteComplete end

local function resetWriteStatus() mspWriteComplete = false end

local function data() return mspData end

local function setUUID(uuid) MSP_API_UUID = uuid end

local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

local function setRebuildOnWrite(rebuild) MSP_REBUILD_ON_WRITE = rebuild end

return {read = read, write = write, setRebuildOnWrite = setRebuildOnWrite, readComplete = readComplete, writeComplete = writeComplete, readValue = readValue, setValue = setValue, resetWriteStatus = resetWriteStatus, setCompleteHandler = handlers.setCompleteHandler, setErrorHandler = handlers.setErrorHandler, data = data, setUUID = setUUID, setTimeout = setTimeout}
