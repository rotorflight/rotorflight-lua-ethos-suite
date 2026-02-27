--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local factory = {}

local type = type
local tostring = tostring
local pairs = pairs
local error = error
local os_clock = os.clock

local function getMspHelper()
    local tasks = rfsuite and rfsuite.tasks
    local msp = tasks and tasks.msp
    return msp and msp.mspHelper
end

local function defaultReadComplete(state, minBytes)
    local data = state.mspData
    return data ~= nil and data.buffer ~= nil and #data.buffer >= (minBytes or 0)
end

local function resolveWriteUUID(spec, state)
    if state.uuid ~= nil then
        return state.uuid
    end

    if spec.writeUuidFallback == true or spec.writeUuidFallback == "unique" then
        local utils = rfsuite and rfsuite.utils
        if utils and type(utils.uuid) == "function" then
            return utils.uuid()
        end
        return tostring(os_clock())
    end

    return nil
end

local function resolveSimulatorResponse(simSpec, state, op, ...)
    if type(simSpec) == "function" then
        return simSpec(state, op, ...)
    end
    return simSpec
end

function factory.create(spec)
    if type(spec) ~= "table" then
        error("factory.create requires spec table")
    end
    if type(spec.name) ~= "string" or spec.name == "" then
        error("factory.create requires spec.name")
    end

    local state = {
        mspData = nil,
        mspWriteComplete = false,
        payloadData = {},
        uuid = nil,
        timeout = nil,
        rebuildOnWrite = (spec.initialRebuildOnWrite == true)
    }

    local completeHandler = nil
    local errorHandler = nil

    local function dispatchError(self, errMsg)
        if errorHandler then
            errorHandler(self, errMsg)
        end
    end

    local function emitComplete(self, buf)
        if completeHandler then
            completeHandler(self, buf)
        end
    end

    local function handleReadReply(self, buf)
        local parser = spec.parseRead
        local helper = getMspHelper()
        local parsed, parseErr

        if parser then
            parsed, parseErr = parser(buf, helper, state)
        else
            parsed = {
                parsed = {},
                buffer = buf,
                receivedBytesCount = #buf
            }
        end

        if not parsed then
            dispatchError(self, parseErr or "parse_failed")
            return
        end

        if parsed.structure == nil and spec.readStructure ~= nil then
            parsed.structure = spec.readStructure
        end

        state.mspData = parsed

        local completeNow
        if spec.readCompleteCondition then
            completeNow = spec.readCompleteCondition(parsed, buf, spec, state)
        else
            completeNow = #buf >= (spec.minBytes or 0)
        end

        if completeNow then
            emitComplete(self, buf)
        end
    end

    local function handleWriteReply(self, buf)
        state.mspWriteComplete = true
        emitComplete(self, buf)
    end

    local function messageErrorHandler(self, errMsg)
        dispatchError(self, errMsg)
    end

    local function read(...)
        if type(spec.customRead) == "function" then
            return spec.customRead(state, emitComplete, dispatchError, ...)
        end

        if spec.readCmd == nil then
            return false, "read_not_supported"
        end

        local payload = nil
        local readBuilder = spec.buildReadPayload
        if type(readBuilder) == "function" then
            local helper = getMspHelper()
            local readErr
            payload, readErr = readBuilder(state.payloadData, state.mspData, helper, state, ...)
            if payload == nil and readErr ~= nil then
                dispatchError(nil, readErr)
                return false, readErr
            end
        elseif spec.readPayload ~= nil then
            payload = spec.readPayload
        end

        local message = {
            command = spec.readCmd,
            apiname = spec.name,
            minBytes = spec.minBytes or 0,
            processReply = handleReadReply,
            errorHandler = messageErrorHandler,
            simulatorResponse = resolveSimulatorResponse(spec.simulatorResponseRead or {}, state, "read", ...),
            uuid = state.uuid,
            timeout = state.timeout
        }

        local readUuidResolver = spec.resolveReadUUID
        if type(readUuidResolver) == "function" then
            message.uuid = readUuidResolver(state, ...)
        end

        if payload ~= nil then
            message.payload = payload
        end

        local timeoutResolver = spec.resolveReadTimeout
        if type(timeoutResolver) == "function" then
            message.timeout = timeoutResolver(state, ...)
        end

        if spec.readStructure ~= nil then
            message.structure = spec.readStructure
        end

        return rfsuite.tasks.msp.mspQueue:add(message)
    end

    local function write(suppliedPayload, ...)
        if type(spec.customWrite) == "function" then
            return spec.customWrite(suppliedPayload, state, emitComplete, dispatchError, ...)
        end

        if spec.writeCmd == nil then
            return false, "write_not_supported"
        end

        local writeStructure = spec.writeStructure
        if spec.writeRequiresStructure == true and suppliedPayload == nil and type(writeStructure) == "table" and #writeStructure == 0 then
            return false, "write_not_implemented"
        end

        local validateWrite = spec.validateWrite
        if type(validateWrite) == "function" then
            local ok, reason = validateWrite(suppliedPayload, state, ...)
            if ok == false then
                return false, reason or "write_validation_failed"
            end
        end

        local payload = suppliedPayload
        if payload == nil then
            local builder = spec.buildWritePayload
            if builder then
                local helper = getMspHelper()
                local buildErr
                payload, buildErr = builder(state.payloadData, state.mspData, helper, state, ...)
                if payload == nil then
                    dispatchError(nil, buildErr or "build_payload_failed")
                    return false, buildErr or "build_payload_failed"
                end
            else
                payload = {}
            end
        end

        local message = {
            command = spec.writeCmd,
            apiname = spec.name,
            payload = payload,
            processReply = handleWriteReply,
            errorHandler = messageErrorHandler,
            simulatorResponse = resolveSimulatorResponse(spec.simulatorResponseWrite or {}, state, "write", suppliedPayload, ...),
            uuid = resolveWriteUUID(spec, state),
            timeout = state.timeout
        }

        local writeUuidResolver = spec.resolveWriteUUID
        if type(writeUuidResolver) == "function" then
            message.uuid = writeUuidResolver(state, suppliedPayload, ...)
        end

        local timeoutResolver = spec.resolveWriteTimeout
        if type(timeoutResolver) == "function" then
            message.timeout = timeoutResolver(state, suppliedPayload, ...)
        end

        return rfsuite.tasks.msp.mspQueue:add(message)
    end

    local function data()
        return state.mspData
    end

    local function readComplete()
        if spec.readCompleteFn then
            return spec.readCompleteFn(state)
        end
        return defaultReadComplete(state, spec.minBytes)
    end

    local function writeComplete()
        return state.mspWriteComplete
    end

    local function readValue(fieldName)
        local d = state.mspData
        if d and d.parsed then
            return d.parsed[fieldName]
        end
        return nil
    end

    local function setValue(fieldName, value)
        state.payloadData[fieldName] = value
    end

    local function resetWriteStatus()
        state.mspWriteComplete = false
    end

    local function setCompleteHandler(fn)
        if type(fn) ~= "function" then
            error("Complete handler requires function")
        end
        completeHandler = fn
    end

    local function setErrorHandler(fn)
        if type(fn) ~= "function" then
            error("Error handler requires function")
        end
        errorHandler = fn
    end

    local function setUUID(uuid)
        state.uuid = uuid
    end

    local function setTimeout(timeout)
        state.timeout = timeout
    end

    local function setRebuildOnWrite(rebuild)
        state.rebuildOnWrite = rebuild
    end

    local api = {
        read = read,
        write = write,
        data = data,
        readComplete = readComplete,
        writeComplete = writeComplete,
        readValue = readValue,
        setValue = setValue,
        resetWriteStatus = resetWriteStatus,
        setCompleteHandler = setCompleteHandler,
        setErrorHandler = setErrorHandler,
        setUUID = setUUID,
        setTimeout = setTimeout,
        setRebuildOnWrite = setRebuildOnWrite
    }

    local methods = spec.methods
    if type(methods) == "table" then
        for name, fn in pairs(methods) do
            if type(fn) == "function" then
                api[name] = function(...)
                    return fn(state, ...)
                end
            end
        end
    end

    local exports = spec.exports
    if type(exports) == "table" then
        for name, value in pairs(exports) do
            api[name] = value
        end
    end

    return api
end

return factory
