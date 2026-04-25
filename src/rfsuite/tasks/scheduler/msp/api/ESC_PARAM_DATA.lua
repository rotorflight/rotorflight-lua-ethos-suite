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

local API_NAME = "ESC_PARAM_DATA"
local MSP_API_CMD_READ = 0x300B
local ESC_ID_COMBINED = 255
local MAX_CHUNK_SIZE = 64
local MIN_READ_BYTES = 4

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

local function buildReadPayload(_, _, _, _, escId, offset, length)
    local targetEscId = clampByte(escId, ESC_ID_COMBINED)
    local chunkOffset = clampByte(offset, 0)
    local chunkLength = clampByte(length, MAX_CHUNK_SIZE)

    if chunkLength == 0 then
        chunkLength = MAX_CHUNK_SIZE
    end
    if chunkLength > MAX_CHUNK_SIZE then
        chunkLength = MAX_CHUNK_SIZE
    end

    return {targetEscId, chunkOffset, chunkLength}
end

local function parseRead(buf, helper)
    if not helper then return nil, "msp_helper_missing" end

    buf.offset = 1

    local escId = helper.readU8(buf)
    local totalLength = helper.readU8(buf)
    local offset = helper.readU8(buf)
    local chunkLength = helper.readU8(buf) or 0

    local data = {}
    for i = 1, chunkLength do
        local value = helper.readU8(buf)
        if value == nil then
            return nil, "short_chunk"
        end
        data[#data + 1] = value
    end

    return {
        parsed = {
            esc_id = escId,
            total_length = totalLength,
            offset = offset,
            chunk_length = chunkLength,
            data = data
        },
        buffer = buf,
        receivedBytesCount = #buf
    }
end

return core.createReadOnlyAPI({
    name = API_NAME,
    readCmd = MSP_API_CMD_READ,
    minApiVersion = {12, 0, 10},
    minBytes = MIN_READ_BYTES,
    parseRead = parseRead,
    buildReadPayload = buildReadPayload,
    exports = {
        MAX_CHUNK_SIZE = MAX_CHUNK_SIZE,
        ESC_ID_COMBINED = ESC_ID_COMBINED
    }
})
