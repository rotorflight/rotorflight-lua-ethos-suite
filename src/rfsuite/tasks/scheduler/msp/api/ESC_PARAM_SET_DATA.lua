--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local msp = rfsuite.tasks and rfsuite.tasks.msp
local core = (msp and msp.apicore) or assert(loadfile("SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"))()
if msp and not msp.apicore then
    msp.apicore = core
end

local API_NAME = "ESC_PARAM_SET_DATA"
local MSP_API_CMD_WRITE = 0x300D
local ESC_ID_COMBINED = 255
local MAX_CHUNK_SIZE = 64

local function validateWrite()
    local armed = rfsuite.utils and rfsuite.utils.resolveArmedState and rfsuite.utils.resolveArmedState()
    if armed then
        if rfsuite.utils and rfsuite.utils.log then
            rfsuite.utils.log("ESC_PARAM_SET_DATA blocked while armed", "info")
        end
        if rfsuite.utils and rfsuite.utils.signalArmedWriteBlocked then
            rfsuite.utils.signalArmedWriteBlocked()
        end
        return false, "armed_blocked"
    end
    return true
end

local function clampByte(value, defaultValue)
    local result = tonumber(value)
    if result == nil then
        result = defaultValue or 0
    end

    result = math.floor(result)
    if result < 0 then result = 0 end
    if result > 255 then result = 255 end
    return result
end

local function normaliseChunkBytes(chunkData)
    local data = {}

    if type(chunkData) == "string" then
        local length = math.min(#chunkData, MAX_CHUNK_SIZE)
        for i = 1, length do
            data[#data + 1] = string.byte(chunkData, i)
        end
        return data
    end

    if type(chunkData) ~= "table" then
        return data
    end

    local length = math.min(#chunkData, MAX_CHUNK_SIZE)
    for i = 1, length do
        data[#data + 1] = clampByte(chunkData[i], 0)
    end

    return data
end

local function buildWritePayload(_, _, _, _, escId, offset, chunkData)
    local payload = {
        clampByte(escId, ESC_ID_COMBINED),
        clampByte(offset, 0)
    }

    local bytes = normaliseChunkBytes(chunkData)
    payload[#payload + 1] = #bytes

    for i = 1, #bytes do
        payload[#payload + 1] = bytes[i]
    end

    return payload
end

return core.createWriteOnlyAPI({
    name = API_NAME,
    writeCmd = MSP_API_CMD_WRITE,
    minApiVersion = {12, 0, 10},
    buildWritePayload = buildWritePayload,
    validateWrite = validateWrite,
    simulatorResponseWrite = {},
    writeUuidFallback = true,
    initialRebuildOnWrite = false
})
