--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")
local core = assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api_core.lua"))()

local API_NAME = "CLI_SETTING"

local MSP_API_CMD_READ  = 196
local MSP_API_CMD_WRITE = 197

local handlers = core.createHandlers()

local mspData = nil
local mspWriteComplete = false

local MSP_API_UUID
local MSP_API_MSG_TIMEOUT

-- ---- helpers ------------------------------------------------------------

local function pushU8(payload, v)
    payload[#payload + 1] = v & 0xFF
end

local function pushU32LE(payload, v)
    -- v is treated as unsigned 32-bit
    pushU8(payload, v & 0xFF)
    pushU8(payload, (v >> 8) & 0xFF)
    pushU8(payload, (v >> 16) & 0xFF)
    pushU8(payload, (v >> 24) & 0xFF)
end

local function u32ToS32(u)
    -- Lua numbers can hold 32-bit exactly
    if u >= 0x80000000 then return u - 0x100000000 end
    return u
end

local function readU8(buf, ofs)
    return rfsuite.tasks.msp.mspHelper.readU8(buf, ofs)
end

local function readU32LE(buf, ofs)
    -- If you already have readU32, use that. Otherwise assemble from bytes.
    local b0 = readU8(buf, ofs) or 0
    local b1 = readU8(buf, ofs + 1) or 0
    local b2 = readU8(buf, ofs + 2) or 0
    local b3 = readU8(buf, ofs + 3) or 0
    return b0 + (b1 << 8) + (b2 << 16) + (b3 << 24)
end

local function buildNamePayload(name)
    local payload = {}
    local len = name and #name or 0
    if len < 1 then return nil end
    if len > 63 then len = 63 end -- matches FC-side guard
    pushU8(payload, len)
    for i = 1, len do
        pushU8(payload, string.byte(name, i))
    end
    return payload
end

local function buildSetPayload(name, valueS32)
    local payload = buildNamePayload(name)
    if not payload then return nil end

    -- Convert signed to unsigned 32-bit pattern for transport
    local u = valueS32
    if u < 0 then u = u + 0x100000000 end
    pushU32LE(payload, u)
    return payload
end

local function parseGetReply(buf)
    -- type(1) + value(4) + min(4) + max(4) + scale(1) + flags(1) = 15 bytes
    if not buf or #buf < 15 then return nil end

    local ofs = 1
    local t = readU8(buf, ofs); ofs = ofs + 1
    local vU = readU32LE(buf, ofs); ofs = ofs + 4
    local mnU = readU32LE(buf, ofs); ofs = ofs + 4
    local mxU = readU32LE(buf, ofs); ofs = ofs + 4
    local scalePow10 = readU8(buf, ofs) or 0; ofs = ofs + 1
    local flags = readU8(buf, ofs) or 0

    return {
        type = t,
        value = u32ToS32(vU),
        min = u32ToS32(mnU),
        max = u32ToS32(mxU),
        scalePow10 = scalePow10,
        flags = flags,
        buffer = buf
    }
end

-- ---- MSP queue messages --------------------------------------------------

local function errorHandlerStatic(self, buf)
    local getError = self.getErrorHandler
    if getError then
        local err = getError()
        if err then err(self, buf) end
    end
end

-- Public: read(name)
local function read(name)
    local payload = buildNamePayload(name)
    if not payload then
        rfsuite.utils.log("CLI_SETTING.read(): invalid name", "debug")
        return
    end

    local message = {
        command = MSP_API_CMD_READ ,
        apiname = API_NAME,
        payload = payload,
        processReply = function(self, buf)
            local parsed = parseGetReply(buf)
            if parsed then
                mspData = { parsed = parsed, buffer = buf }
                local completeHandler = handlers.getCompleteHandler()
                if completeHandler then completeHandler(self, buf) end
            else
                local errorHandler = handlers.getErrorHandler()
                if errorHandler then errorHandler(self, buf) end
            end
        end,
        errorHandler = function(self, buf)
            local errorHandler = handlers.getErrorHandler()
            if errorHandler then errorHandler(self, buf) end
        end,
        simulatorResponse = {}, -- optional: you can populate a fake 15-byte reply if needed
        uuid = MSP_API_UUID,
        timeout = MSP_API_MSG_TIMEOUT
    }

    rfsuite.tasks.msp.mspQueue:add(message)
end

-- Public: write(name, valueS32)
local function write(name, valueS32)
    local payload = buildSetPayload(name, valueS32 or 0)
    if not payload then
        rfsuite.utils.log("CLI_SETTING.write(): invalid name", "debug")
        return
    end

    mspWriteComplete = false

    local uuid = MSP_API_UUID or (rfsuite.utils and rfsuite.utils.uuid and rfsuite.utils.uuid()) or tostring(os.clock())

    local message = {
        command = MSP_API_CMD_WRITE,
        apiname = API_NAME,
        payload = payload,
        processReply = function(self, buf)
            -- reply: u8 success
            local ok = (buf and #buf >= 1 and readU8(buf, 1) == 1)
            mspWriteComplete = ok and true or false

            local completeHandler = handlers.getCompleteHandler()
            if completeHandler then completeHandler(self, buf) end

            if not ok then
                local errorHandler = handlers.getErrorHandler()
                if errorHandler then errorHandler(self, buf) end
            end
        end,
        errorHandler = errorHandlerStatic,
        simulatorResponse = {1},
        uuid = uuid,
        timeout = MSP_API_MSG_TIMEOUT,
        getCompleteHandler = handlers.getCompleteHandler,
        getErrorHandler = handlers.getErrorHandler
    }

    rfsuite.tasks.msp.mspQueue:add(message)
end

local function readValue()
    -- returns parsed table: {type,value,min,max,scalePow10,flags}
    if mspData and mspData.parsed then return mspData.parsed end
    return nil
end

local function readComplete()
    return mspData ~= nil and mspData.buffer ~= nil and #mspData.buffer >= 15
end

local function writeComplete()
    return mspWriteComplete
end

local function resetWriteStatus()
    mspWriteComplete = false
end

local function data()
    return mspData
end

local function setUUID(uuid) MSP_API_UUID = uuid end
local function setTimeout(timeout) MSP_API_MSG_TIMEOUT = timeout end

return {
    read = read,
    write = write,

    readValue = readValue,
    readComplete = readComplete,

    writeComplete = writeComplete,
    resetWriteStatus = resetWriteStatus,

    data = data,
    setUUID = setUUID,
    setTimeout = setTimeout,

    setCompleteHandler = handlers.setCompleteHandler,
    setErrorHandler = handlers.setErrorHandler
}
