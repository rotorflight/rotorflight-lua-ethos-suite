--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local escparamv2 = {}

local ESC_ID_COMBINED = 255
local ESC_CAP_PARAM_READ = 0x02
local ESC_CAP_PARAM_WRITE = 0x04
local ESC_WRITE_STATE_DONE = 4
local ESC_WRITE_STATE_FAILED = 5
local DEFAULT_CHUNK_SIZE = 64

local function noop() end

local function detachHandlers(api)
    if not api then return end
    if api.setCompleteHandler then pcall(api.setCompleteHandler, noop) end
    if api.setErrorHandler then pcall(api.setErrorHandler, noop) end
end

local function hasFlag(value, flag)
    if type(value) ~= "number" or type(flag) ~= "number" or flag <= 0 then
        return false
    end

    return math.floor(value / flag) % 2 == 1
end

local function clampChunkSize(value)
    local chunkSize = tonumber(value)
    if chunkSize == nil then
        chunkSize = DEFAULT_CHUNK_SIZE
    end

    chunkSize = math.floor(chunkSize)
    if chunkSize < 1 then chunkSize = 1 end
    if chunkSize > DEFAULT_CHUNK_SIZE then chunkSize = DEFAULT_CHUNK_SIZE end
    return chunkSize
end

local function normaliseEscId(escId)
    local targetEscId = tonumber(escId)
    if targetEscId == nil then
        targetEscId = ESC_ID_COMBINED
    end

    targetEscId = math.floor(targetEscId)
    if targetEscId < 0 then targetEscId = 0 end
    if targetEscId > 255 then targetEscId = 255 end
    return targetEscId
end

local function normaliseBytes(data)
    local bytes = {}

    if type(data) == "string" then
        for i = 1, #data do
            bytes[#bytes + 1] = string.byte(data, i)
        end
        return bytes
    end

    if type(data) ~= "table" then
        return bytes
    end

    for i = 1, #data do
        local value = tonumber(data[i]) or 0
        value = math.floor(value)
        if value < 0 then value = 0 end
        if value > 255 then value = 255 end
        bytes[#bytes + 1] = value
    end

    return bytes
end

local function copyBytes(bytes)
    local copied = {}
    if type(bytes) ~= "table" then
        return copied
    end

    for i = 1, #bytes do
        copied[i] = bytes[i]
    end

    return copied
end

local function sliceBytes(bytes, offset, length)
    local chunk = {}
    if type(bytes) ~= "table" then
        return chunk
    end

    local lastIndex = math.min(#bytes, offset + length)
    for index = offset + 1, lastIndex do
        chunk[#chunk + 1] = bytes[index]
    end

    return chunk
end

function escparamv2.new()
    local state = {
        pending = false,
        mode = nil,
        escId = ESC_ID_COMBINED,
        totalLength = 0,
        chunkSize = DEFAULT_CHUNK_SIZE,
        offset = 0,
        readBuffer = nil,
        writeBuffer = nil,
        lastWriteChunkLength = 0,
        infoApi = nil,
        infoApiName = nil,
        readDataApi = nil,
        readDataApiName = nil,
        beginApi = nil,
        beginApiName = nil,
        setDataApi = nil,
        setDataApiName = nil,
        commitApi = nil,
        commitApiName = nil,
        statusApi = nil,
        statusApiName = nil
    }

    local currentOnComplete = nil
    local currentOnError = nil

    local function isAvailable()
        return rfsuite.utils and rfsuite.utils.apiVersionCompare and rfsuite.utils.apiVersionCompare(">=", {12, 0, 10})
    end

    local function loadApi(slot, slotName, apiName)
        if state[slot] and state[slotName] == apiName then
            return state[slot]
        end

        state[slot] = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.load and
            rfsuite.tasks.msp.api.load(apiName) or nil
        state[slotName] = state[slot] and apiName or nil
        return state[slot]
    end

    local function clearCallbacks()
        currentOnComplete = nil
        currentOnError = nil
    end

    local function reset()
        detachHandlers(state.infoApi)
        detachHandlers(state.readDataApi)
        detachHandlers(state.beginApi)
        detachHandlers(state.setDataApi)
        detachHandlers(state.commitApi)
        detachHandlers(state.statusApi)
        state.pending = false
        state.mode = nil
        state.escId = ESC_ID_COMBINED
        state.totalLength = 0
        state.chunkSize = DEFAULT_CHUNK_SIZE
        state.offset = 0
        state.readBuffer = nil
        state.writeBuffer = nil
        state.lastWriteChunkLength = 0
        clearCallbacks()
    end

    local function finish(result)
        state.pending = false
        state.mode = nil
        local onComplete = currentOnComplete
        clearCallbacks()
        if type(onComplete) == "function" then
            onComplete(result)
        end
    end

    local function fail(reason)
        state.pending = false
        state.mode = nil
        local onError = currentOnError
        clearCallbacks()
        if type(onError) == "function" then
            onError(reason)
        end
    end

    local function readStatus(onComplete, onError)
        if not isAvailable() then
            return false, "unsupported"
        end
        if state.pending then
            return false, "busy"
        end

        local statusApi = loadApi("statusApi", "statusApiName", "ESC_WRITE_STATUS")
        if not statusApi then
            return false, "api_unavailable"
        end

        state.pending = true
        state.mode = "status"
        currentOnComplete = onComplete
        currentOnError = onError

        statusApi.setCompleteHandler(function()
            finish({
                op_id = statusApi.readValue("op_id") or 0,
                esc_id = statusApi.readValue("esc_id") or ESC_ID_COMBINED,
                protocol = statusApi.readValue("protocol") or 0,
                signature = statusApi.readValue("signature") or 0,
                state = statusApi.readValue("state") or 0,
                error = statusApi.readValue("error") or 0,
                done = (statusApi.readValue("state") or 0) == ESC_WRITE_STATE_DONE,
                failed = (statusApi.readValue("state") or 0) == ESC_WRITE_STATE_FAILED
            })
        end)
        statusApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_write_status_error")
        end)

        local ok, reason = statusApi.read()
        if not ok then
            state.pending = false
            state.mode = nil
            clearCallbacks()
            return false, reason
        end

        return true
    end

    local function fetch(onComplete, onError, escId)
        if not isAvailable() then
            return false, "unsupported"
        end
        if state.pending then
            return false, "busy"
        end

        local infoApi = loadApi("infoApi", "infoApiName", "ESC_INFO")
        local readDataApi = loadApi("readDataApi", "readDataApiName", "ESC_PARAM_DATA")
        if not infoApi or not readDataApi then
            return false, "api_unavailable"
        end

        state.pending = true
        state.mode = "read"
        state.escId = normaliseEscId(escId)
        state.offset = 0
        state.totalLength = 0
        state.chunkSize = DEFAULT_CHUNK_SIZE
        state.readBuffer = {}
        currentOnComplete = onComplete
        currentOnError = onError

        local function queueNextRead()
            local remaining = state.totalLength - state.offset
            if remaining <= 0 then
                finish({
                    esc_id = state.escId,
                    total_length = state.totalLength,
                    chunk_size = state.chunkSize,
                    data = copyBytes(state.readBuffer)
                })
                return
            end

            local requestLength = math.min(remaining, state.chunkSize)
            local ok, reason = readDataApi.read(state.escId, state.offset, requestLength)
            if not ok then
                fail(reason or "esc_param_data_queue_failed")
            end
        end

        readDataApi.setCompleteHandler(function()
            local chunkEscId = tonumber(readDataApi.readValue("esc_id"))
            local totalLength = tonumber(readDataApi.readValue("total_length")) or state.totalLength
            local offset = tonumber(readDataApi.readValue("offset")) or state.offset
            local chunkLength = tonumber(readDataApi.readValue("chunk_length")) or 0
            local data = readDataApi.readValue("data") or {}

            if chunkEscId ~= nil then
                state.escId = chunkEscId
            end
            state.totalLength = totalLength

            if chunkLength ~= #data then
                chunkLength = #data
            end

            for i = 1, chunkLength do
                state.readBuffer[offset + i] = data[i]
            end

            state.offset = offset + chunkLength
            queueNextRead()
        end)
        readDataApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_param_data_error")
        end)

        infoApi.setCompleteHandler(function()
            local capabilities = tonumber(infoApi.readValue("capabilities")) or 0
            local parameterBytes = tonumber(infoApi.readValue("parameter_bytes")) or 0
            local maxChunkSize = tonumber(infoApi.readValue("max_chunk_size")) or DEFAULT_CHUNK_SIZE
            local resolvedEscId = tonumber(infoApi.readValue("esc_id"))

            if resolvedEscId ~= nil then
                state.escId = resolvedEscId
            end

            if not hasFlag(capabilities, ESC_CAP_PARAM_READ) then
                fail("param_read_unsupported")
                return
            end
            if parameterBytes <= 0 then
                fail("param_buffer_empty")
                return
            end

            state.totalLength = parameterBytes
            state.chunkSize = clampChunkSize(maxChunkSize)
            queueNextRead()
        end)
        infoApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_info_error")
        end)

        local ok, reason = infoApi.read(state.escId)
        if not ok then
            state.pending = false
            state.mode = nil
            clearCallbacks()
            return false, reason
        end

        return true
    end

    local function write(data, onComplete, onError, escId)
        if not isAvailable() then
            return false, "unsupported"
        end
        if state.pending then
            return false, "busy"
        end

        local writeBuffer = normaliseBytes(data)
        if #writeBuffer == 0 then
            return false, "no_data"
        end

        local infoApi = loadApi("infoApi", "infoApiName", "ESC_INFO")
        local beginApi = loadApi("beginApi", "beginApiName", "ESC_PARAM_BEGIN")
        local setDataApi = loadApi("setDataApi", "setDataApiName", "ESC_PARAM_SET_DATA")
        local commitApi = loadApi("commitApi", "commitApiName", "ESC_PARAM_COMMIT")
        if not infoApi or not beginApi or not setDataApi or not commitApi then
            return false, "api_unavailable"
        end

        state.pending = true
        state.mode = "write"
        state.escId = normaliseEscId(escId)
        state.totalLength = #writeBuffer
        state.chunkSize = DEFAULT_CHUNK_SIZE
        state.offset = 0
        state.writeBuffer = writeBuffer
        state.lastWriteChunkLength = 0
        currentOnComplete = onComplete
        currentOnError = onError

        local function queueNextWrite()
            if state.offset >= #state.writeBuffer then
                local ok, reason = commitApi.write(nil, state.escId)
                if not ok then
                    fail(reason or "esc_param_commit_queue_failed")
                end
                return
            end

            local remaining = #state.writeBuffer - state.offset
            local chunkLength = math.min(remaining, state.chunkSize)
            local chunkData = sliceBytes(state.writeBuffer, state.offset, chunkLength)
            state.lastWriteChunkLength = #chunkData

            local ok, reason = setDataApi.write(nil, state.escId, state.offset, chunkData)
            if not ok then
                fail(reason or "esc_param_set_data_queue_failed")
            end
        end

        commitApi.setCompleteHandler(function()
            finish({
                esc_id = state.escId,
                total_length = #state.writeBuffer,
                chunk_size = state.chunkSize,
                committed = true
            })
        end)
        commitApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_param_commit_error")
        end)

        setDataApi.setCompleteHandler(function()
            state.offset = state.offset + state.lastWriteChunkLength
            queueNextWrite()
        end)
        setDataApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_param_set_data_error")
        end)

        beginApi.setCompleteHandler(function()
            state.offset = 0
            queueNextWrite()
        end)
        beginApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_param_begin_error")
        end)

        infoApi.setCompleteHandler(function()
            local capabilities = tonumber(infoApi.readValue("capabilities")) or 0
            local parameterBytes = tonumber(infoApi.readValue("parameter_bytes")) or 0
            local maxChunkSize = tonumber(infoApi.readValue("max_chunk_size")) or DEFAULT_CHUNK_SIZE
            local resolvedEscId = tonumber(infoApi.readValue("esc_id"))

            if resolvedEscId ~= nil then
                state.escId = resolvedEscId
            end

            if not hasFlag(capabilities, ESC_CAP_PARAM_WRITE) then
                fail("param_write_unsupported")
                return
            end
            if parameterBytes <= 0 then
                fail("param_buffer_empty")
                return
            end
            if #state.writeBuffer ~= parameterBytes then
                fail("param_length_mismatch")
                return
            end

            state.chunkSize = clampChunkSize(maxChunkSize)

            local ok, reason = beginApi.write(nil, state.escId)
            if not ok then
                fail(reason or "esc_param_begin_queue_failed")
            end
        end)
        infoApi.setErrorHandler(function(_, reason)
            fail(reason or "esc_info_error")
        end)

        local ok, reason = infoApi.read(state.escId)
        if not ok then
            state.pending = false
            state.mode = nil
            clearCallbacks()
            return false, reason
        end

        return true
    end

    return {
        isAvailable = isAvailable,
        pending = function()
            return state.pending
        end,
        fetch = fetch,
        write = write,
        readStatus = readStatus,
        reset = reset
    }
end

return escparamv2
