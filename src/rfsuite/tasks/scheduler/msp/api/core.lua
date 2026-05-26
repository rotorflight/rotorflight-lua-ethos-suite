--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.utils
local type = type
local error = error
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local loadfile = loadfile
local os_clock = os.clock
local math_floor = math.floor
local math_min = math.min
local table_insert = table.insert
local string_format = string.format

local core = {}

local mspHelper = rfsuite.tasks.msp.mspHelper
local isSim = (system and system.getVersion and system.getVersion().simulation) == true
local EMPTY_SIM_RESPONSE = {}

local TYPE_SIZES = {
    U8 = 1, S8 = 1, U16 = 2, S16 = 2, U24 = 3, S24 = 3, U32 = 4, S32 = 4,
    U40 = 5, S40 = 5, U48 = 6, S48 = 6, U56 = 7, S56 = 7, U64 = 8, S64 = 8,
    U72 = 9, S72 = 9, U80 = 10, S80 = 10, U88 = 11, S88 = 11,
    U96 = 12, S96 = 12, U104 = 13, S104 = 13, U112 = 14, S112 = 14,
    U120 = 15, S120 = 15, U128 = 16, S128 = 16, U256 = 32, S256 = 32
}

local FIELD_NAME = 1
local FIELD_TYPE = 2
local FIELD_MIN = 3
local FIELD_MAX = 4
local FIELD_DEFAULT = 5
local FIELD_UNIT = 6
local FIELD_DECIMALS = 7
local FIELD_SCALE = 8
local FIELD_STEP = 9
local FIELD_MULT = 10
local FIELD_TABLE = 11
local FIELD_TABLE_IDX_INC = 12
local FIELD_MANDATORY = 13
local FIELD_BYTEORDER = 14
local FIELD_TABLE_ETHOS = 15
local FIELD_OFFSET = 16
local FIELD_XVALS = 17

local function resolveSimulatorResponse(simSpec, state, op, ...)
    if type(simSpec) == "function" then
        return simSpec(state, op, ...)
    end
    return simSpec
end

local function operationSupported(spec, op)
    local minVersion = spec[op .. "MinApiVersion"] or spec.minApiVersion
    local maxVersion = spec[op .. "MaxApiVersion"] or spec.maxApiVersion

    if type(minVersion) == "table" and utils.apiVersionCompare("<", minVersion) then
        return false
    end

    if type(maxVersion) == "table" and utils.apiVersionCompare(">", maxVersion) then
        return false
    end

    return true
end

local function resolveWriteUUID(spec, state)
    if state.uuid ~= nil then
        return state.uuid
    end

    if spec.writeUuidFallback == true or spec.writeUuidFallback == "unique" then
        if utils and type(utils.uuid) == "function" then
            return utils.uuid()
        end
        return tostring(os_clock())
    end

    return nil
end

local function applyFieldMeta(target, tuple)
    local min = tuple[FIELD_MIN]
    local max = tuple[FIELD_MAX]
    local default = tuple[FIELD_DEFAULT]
    local unit = tuple[FIELD_UNIT]
    local decimals = tuple[FIELD_DECIMALS]
    local scale = tuple[FIELD_SCALE]
    local step = tuple[FIELD_STEP]
    local mult = tuple[FIELD_MULT]
    local tableValues = tuple[FIELD_TABLE]
    local tableIdxInc = tuple[FIELD_TABLE_IDX_INC]
    local mandatory = tuple[FIELD_MANDATORY]
    local byteorder = tuple[FIELD_BYTEORDER]
    local tableEthos = tuple[FIELD_TABLE_ETHOS]
    local offset = tuple[FIELD_OFFSET]
    local xvals = tuple[FIELD_XVALS]

    if min ~= nil then target.min = min end
    if max ~= nil then target.max = max end
    if default ~= nil then target.default = default end
    if unit ~= nil then target.unit = unit end
    if decimals ~= nil then target.decimals = decimals end
    if scale ~= nil then target.scale = scale end
    if step ~= nil then target.step = step end
    if mult ~= nil then target.mult = mult end
    if tableValues ~= nil then target.table = tableValues end
    if tableIdxInc ~= nil then target.tableIdxInc = tableIdxInc end
    if mandatory ~= nil then target.mandatory = mandatory end
    if byteorder ~= nil then target.byteorder = byteorder end
    if tableEthos ~= nil then target.tableEthos = tableEthos end
    if offset ~= nil then target.offset = offset end
    if xvals ~= nil then target.xvals = xvals end
end

local function buildRuntimeStructure(fieldSpec)
    local structure = {}
    local names = {}
    local readers = {}
    local positionmap = {}
    local minBytes = 0
    local currentByte = 1

    for _, tuple in ipairs(fieldSpec) do
        local fieldName = tuple[FIELD_NAME]
        local typeName = tuple[FIELD_TYPE]
        local reader = mspHelper["read" .. typeName]
        if not reader then
            error("Unknown MSP type in api structure: " .. tostring(typeName))
        end

        local fieldSize = TYPE_SIZES[typeName]
        if not fieldSize then
            error("Missing MSP size for api type: " .. tostring(typeName))
        end

        local field = {
            field = fieldName,
            type = typeName
        }
        applyFieldMeta(field, tuple)

        structure[#structure + 1] = field
        names[#names + 1] = fieldName
        readers[#readers + 1] = reader
        positionmap[fieldName] = {start = currentByte, size = fieldSize}

        if field.mandatory ~= false then
            minBytes = minBytes + fieldSize
        end

        currentByte = currentByte + fieldSize
    end

    return structure, names, readers, minBytes, positionmap
end

function core.buildStructure(fieldSpec)
    local structure, _, _, minBytes, positionmap = buildRuntimeStructure(fieldSpec)
    return structure, minBytes, positionmap
end

function core.prepareReadPlan(fieldSpec)
    local names = {}
    local readers = {}
    local minBytes = 0

    for i = 1, #fieldSpec, 2 do
        local fieldName = fieldSpec[i]
        local typeName = fieldSpec[i + 1]

        local reader = mspHelper["read" .. typeName]
        if not reader then
            error("Unknown MSP type in api plan: " .. tostring(typeName))
        end
        names[#names + 1] = fieldName
        readers[#readers + 1] = reader
        minBytes = minBytes + (TYPE_SIZES[typeName] or 1)
    end

    return names, readers, minBytes
end

function core.parseReadPlan(buf, names, readers)
    local parsed = {}
    buf.offset = 1

    for i = 1, #names do
        parsed[names[i]] = readers[i](buf)
    end

    return parsed
end

function core.parseStructure(apiName, buf, structure)
    local parsedData = {}
    local positionmap = {}
    local currentByte = 1

    buf.offset = 1

    for _, field in ipairs(structure) do
        local readFunction = mspHelper["read" .. field.type]
        if not readFunction then
            return nil, "unknown_type"
        end

        parsedData[field.field] = readFunction(buf, field.byteorder or "little")

        local size = TYPE_SIZES[field.type] or 1
        positionmap[field.field] = {start = currentByte, size = size}
        currentByte = currentByte + size
    end

    return {
        parsed = parsedData,
        buffer = buf,
        structure = structure,
        positionmap = positionmap,
        other = nil,
        receivedBytesCount = math_floor((buf.offset or 1) - 1)
    }
end

function core.buildPayload(apiName, payloadData, writeStructure, rebuildOnWrite)
    return core.buildWritePayload(apiName, payloadData, writeStructure, rebuildOnWrite == true)
end

function core.buildFullPayload(apiName, payloadData, writeStructure)
    local byteStream = {}
    local actualFields = {}

    if rfsuite.app.Page and rfsuite.app.Page.apidata then
        for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do
            if field.apikey then
                actualFields[field.apikey] = field
            end
        end
    end

    for _, fieldDef in ipairs(writeStructure) do
        local name = fieldDef.field
        local actual = actualFields[name]
        if actual then
            fieldDef.scale = fieldDef.scale or actual.scale
            fieldDef.mult = fieldDef.mult or actual.mult
            fieldDef.step = fieldDef.step or actual.step
            fieldDef.min = fieldDef.min or actual.min
            fieldDef.max = fieldDef.max or actual.max
            fieldDef.decimals = fieldDef.decimals or actual.decimals
        end

        local value = payloadData[name] or fieldDef.default or 0
        local scale = actual and (fieldDef.scale or 1) or 1
        value = math_floor(value * scale + 0.5)

        local writeFunction = mspHelper["write" .. fieldDef.type]
        if not writeFunction then
            error("Unknown type " .. tostring(fieldDef.type))
        end

        local tmp = {}
        if fieldDef.byteorder then
            writeFunction(tmp, value, fieldDef.byteorder)
        else
            writeFunction(tmp, value)
        end

        for _, b in ipairs(tmp) do
            table_insert(byteStream, b)
        end

        utils.log(string_format("[buildFullPayload] Wrote field '%s' = %d", name, value), "debug")
    end

    return byteStream
end

function core.buildDeltaPayload(apiName, payloadData, writeStructure, positionmap, receivedBytes, receivedBytesCount)
    local byteStream = {}
    for i = 1, receivedBytesCount or 0 do
        byteStream[i] = receivedBytes and receivedBytes[i] or 0
    end

    local editableFields = {}
    for idx, _ in ipairs(rfsuite.app.formFields or {}) do
        local pageField = rfsuite.app.Page and rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.formdata.fields[idx]
        if pageField and pageField.apikey then
            local key = pageField.apikey:match("([^%-]+)%-%>") or pageField.apikey
            editableFields[key] = true
        end
    end

    local actualFields = {}
    if rfsuite.app.Page and rfsuite.app.Page.apidata then
        for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do
            if field.api and not field.apikey then
                local mspapi, apikey = string.match(field.api, "([^:]+):(.+)")
                for i, apiNameEntry in ipairs(rfsuite.app.Page.apidata.api) do
                    if apiNameEntry == mspapi then
                        mspapi = i
                        break
                    end
                end
                field.apikey = apikey
                field.mspapi = mspapi
            end

            if field.apikey then
                actualFields[field.apikey] = field
            end
        end
    end

    for _, fieldDef in ipairs(writeStructure) do
        local name = fieldDef.field
        if not editableFields[name] then
            goto continue
        end

        local actualField = actualFields[name]
        if actualField then
            fieldDef.scale = fieldDef.scale or actualField.scale
            fieldDef.mult = fieldDef.mult or actualField.mult
            fieldDef.step = fieldDef.step or actualField.step
            fieldDef.min = fieldDef.min or actualField.min
            fieldDef.max = fieldDef.max or actualField.max
        end

        local value = payloadData[name] or fieldDef.default or 0
        local scale = fieldDef.scale or 1
        value = math_floor(value * scale + 0.5)

        local writeFunction = mspHelper["write" .. fieldDef.type]
        if not writeFunction then
            error("Unknown type " .. tostring(fieldDef.type))
        end

        local tmp = {}
        if fieldDef.byteorder then
            writeFunction(tmp, value, fieldDef.byteorder)
        else
            writeFunction(tmp, value)
        end

        local pm = positionmap[name]
        if type(pm) == "table" and pm.start and pm.size then
            local maxBytes = math_min(pm.size, #tmp)
            for i = 1, maxBytes do
                local pos = pm.start + i - 1
                if pos <= receivedBytesCount then
                    byteStream[pos] = tmp[i]
                end
            end
        elseif pm then
            for idx, pos in ipairs(pm) do
                if pos <= receivedBytesCount then
                    byteStream[pos] = tmp[idx]
                end
            end
        end

        ::continue::
    end

    return byteStream
end

function core.buildWritePayload(apiName, payloadData, writeStructure, noDelta)
    if not rfsuite.app.Page then
        utils.log("[buildWritePayload] No page context", "info")
        return core.buildFullPayload(apiName, payloadData, writeStructure)
    end

    local apidata = rfsuite.tasks and rfsuite.tasks.msp and rfsuite.tasks.msp.api and rfsuite.tasks.msp.api.apidata
    local positionmap = apidata and apidata.positionmap and apidata.positionmap[apiName]
    local receivedBytes = apidata and apidata.receivedBytes and apidata.receivedBytes[apiName]
    local receivedBytesCount = apidata and apidata.receivedBytesCount and apidata.receivedBytesCount[apiName]

    local useDelta = positionmap and receivedBytes and receivedBytesCount
    if noDelta == true then
        useDelta = false
    end

    if useDelta then
        if apidata then
            apidata._lastWriteMode = apidata._lastWriteMode or {}
            apidata._lastWriteMode[apiName] = "delta"
        end
        return core.buildDeltaPayload(apiName, payloadData, writeStructure, positionmap, receivedBytes, receivedBytesCount)
    end

    if apidata then
        apidata._lastWriteMode = apidata._lastWriteMode or {}
        apidata._lastWriteMode[apiName] = (noDelta == true) and "rebuild" or "full"
    end
    return core.buildFullPayload(apiName, payloadData, writeStructure)
end

function core.simResponse(bytes)
    if not isSim then return nil end
    return bytes or {}
end

function core.createReadOnlyAPI(spec)
    if type(spec) ~= "table" then
        error("api.createReadOnlyAPI requires spec table")
    end
    if type(spec.name) ~= "string" or spec.name == "" then
        error("api.createReadOnlyAPI requires spec.name")
    end
    if spec.readCmd == nil then
        error("api.createReadOnlyAPI requires spec.readCmd")
    end
    local customParser = spec.parseRead
    if customParser == nil and type(spec.fields) ~= "table" then
        error("api.createReadOnlyAPI requires spec.fields")
    end

    local fieldNames = nil
    local fieldReaders = nil
    local minBytes = tonumber(spec.minBytes) or 0
    if customParser == nil then
        fieldNames, fieldReaders, minBytes = core.prepareReadPlan(spec.fields)
    end
    local completeHandler = nil
    local errorHandler = nil
    local state = {
        mspData = nil,
        timeout = nil,
        uuid = nil
    }
    local onError

    local function processReply(self, buf)
        if type(customParser) == "function" then
            local parsed, parseErr = customParser(buf, mspHelper, state)
            if not parsed then
                onError(self, parseErr or "parse_failed")
                return
            end
            if parsed.structure == nil then
                parsed.structure = {}
            end
            if parsed.receivedBytesCount == nil then
                parsed.receivedBytesCount = #buf
            end
            state.mspData = parsed
        else
            state.mspData = {
                parsed = core.parseReadPlan(buf, fieldNames, fieldReaders),
                structure = {},
                buffer = buf,
                positionmap = nil,
                other = nil,
                receivedBytesCount = #buf
            }
        end
        if completeHandler then
            completeHandler(self, buf)
        end
    end

    onError = function(self, errMsg)
        if errorHandler then
            errorHandler(self, errMsg)
        end
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

    local function read(...)
        if not operationSupported(spec, "read") then
            return false, "read_not_supported"
        end

        local payload = nil
        local readBuilder = spec.buildReadPayload
        if type(readBuilder) == "function" then
            payload = readBuilder(state.payloadData, state.mspData, mspHelper, state, ...)
        elseif spec.readPayload ~= nil then
            payload = spec.readPayload
        end

        local message = {
            command = spec.readCmd,
            apiname = spec.name,
            minBytes = minBytes,
            processReply = processReply,
            errorHandler = onError,
            simulatorResponse = spec.simulatorResponseRead,
            timeout = state.timeout,
            uuid = state.uuid,
            retryOnErrorReply = (spec.readRetryOnErrorReply == true),
            retryBackoff = spec.readRetryBackoff,
            completeOnErrorReplyAttempt = spec.readCompleteOnErrorReplyAttempt
        }

        local readUuidResolver = spec.resolveReadUUID
        if type(readUuidResolver) == "function" then
            message.uuid = readUuidResolver(state, ...)
        end

        if payload ~= nil then
            message.payload = payload
        end

        return rfsuite.tasks.msp.mspQueue:add(message)
    end

    local function write()
        return false, "write_not_supported"
    end

    local function readValue(fieldName)
        local d = state.mspData
        if d and d.parsed then
            return d.parsed[fieldName]
        end
        return nil
    end

    local function data()
        return state.mspData
    end

    local function readComplete()
        local d = state.mspData
        return d ~= nil and (d.receivedBytesCount or 0) >= minBytes
    end

    local function writeComplete()
        return false
    end

    local function setUUID(uuid)
        state.uuid = uuid
    end

    local function setTimeout(timeout)
        state.timeout = timeout
    end

    local function setValue()
    end

    local function resetWriteStatus()
    end

    local function setRebuildOnWrite()
    end

    local api = {
        read = read,
        write = write,
        data = data,
        readValue = readValue,
        readComplete = readComplete,
        writeComplete = writeComplete,
        setValue = setValue,
        resetWriteStatus = resetWriteStatus,
        setCompleteHandler = setCompleteHandler,
        setErrorHandler = setErrorHandler,
        setUUID = setUUID,
        setTimeout = setTimeout,
        setRebuildOnWrite = setRebuildOnWrite,
        __rfReadStructure = {},
        __rfWriteStructure = {}
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

function core.createConfigAPI(spec)
    if type(spec) ~= "table" then
        error("api.createConfigAPI requires spec table")
    end
    if type(spec.name) ~= "string" or spec.name == "" then
        error("api.createConfigAPI requires spec.name")
    end
    if spec.readCmd == nil then
        error("api.createConfigAPI requires spec.readCmd")
    end
    if type(spec.fields) ~= "table" then
        error("api.createConfigAPI requires spec.fields")
    end

    local readStructure, fieldNames, fieldReaders, minBytes, positionmap = buildRuntimeStructure(spec.fields)
    local writeStructure = readStructure
    if type(spec.writeFields) == "table" then
        writeStructure = select(1, buildRuntimeStructure(spec.writeFields))
    end

    local completeHandler = nil
    local errorHandler = nil
    local state = {
        mspData = nil,
        mspWriteComplete = false,
        payloadData = {},
        timeout = nil,
        uuid = nil,
        rebuildOnWrite = (spec.initialRebuildOnWrite == true)
    }

    local function emitComplete(self, buf)
        if completeHandler then
            completeHandler(self, buf)
        end
    end

    local function dispatchError(self, errMsg)
        if errorHandler then
            errorHandler(self, errMsg)
        end
    end

    local function handleReadReply(self, buf)
        local customParser = spec.parseRead
        if type(customParser) == "function" then
            local parsed, parseErr = customParser(buf, mspHelper, state)
            if not parsed then
                dispatchError(self, parseErr or "parse_failed")
                return
            end
            if parsed.structure == nil then
                parsed.structure = readStructure
            end
            if parsed.positionmap == nil then
                parsed.positionmap = positionmap
            end
            if parsed.receivedBytesCount == nil then
                parsed.receivedBytesCount = #buf
            end
            state.mspData = parsed
        else
            state.mspData = {
                parsed = core.parseReadPlan(buf, fieldNames, fieldReaders),
                structure = readStructure,
                buffer = buf,
                positionmap = positionmap,
                other = nil,
                receivedBytesCount = #buf
            }
        end
        emitComplete(self, buf)
    end

    local function handleWriteReply(self, buf)
        state.mspWriteComplete = true
        emitComplete(self, buf)
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

    local function read(...)
        if not operationSupported(spec, "read") then
            return false, "read_not_supported"
        end

        local payload = nil
        local readBuilder = spec.buildReadPayload
        if type(readBuilder) == "function" then
            payload = readBuilder(state.payloadData, state.mspData, mspHelper, state, ...)
        elseif spec.readPayload ~= nil then
            payload = spec.readPayload
        end

        local message = {
            command = spec.readCmd,
            apiname = spec.name,
            minBytes = minBytes,
            processReply = handleReadReply,
            errorHandler = dispatchError,
            simulatorResponse = spec.simulatorResponseRead,
            timeout = state.timeout,
            uuid = state.uuid,
            retryOnErrorReply = (spec.readRetryOnErrorReply == true),
            retryBackoff = spec.readRetryBackoff,
            completeOnErrorReplyAttempt = spec.readCompleteOnErrorReplyAttempt
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

        return rfsuite.tasks.msp.mspQueue:add(message)
    end

    local function write(suppliedPayload, ...)
        if not operationSupported(spec, "write") then
            return false, "write_not_supported"
        end
        if spec.writeCmd == nil then
            return false, "write_not_supported"
        end

        local payload = suppliedPayload
        if payload == nil then
            local writeBuilder = spec.buildWritePayload
            if type(writeBuilder) == "function" then
                payload = writeBuilder(state.payloadData, state.mspData, mspHelper, state, ...)
            else
                payload = core.buildWritePayload(
                    spec.name,
                    state.payloadData,
                    writeStructure,
                    state.rebuildOnWrite == true
                )
            end
        end

        local message = {
            command = spec.writeCmd,
            apiname = spec.name,
            payload = payload,
            processReply = handleWriteReply,
            errorHandler = dispatchError,
            simulatorResponse = spec.simulatorResponseWrite or EMPTY_SIM_RESPONSE,
            timeout = state.timeout,
            uuid = resolveWriteUUID(spec, state)
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

    local function readComplete()
        local d = state.mspData
        return d ~= nil and (d.receivedBytesCount or 0) >= minBytes
    end

    local function writeComplete()
        return state.mspWriteComplete == true
    end

    local function resetWriteStatus()
        state.mspWriteComplete = false
    end

    local function setUUID(uuid)
        state.uuid = uuid
    end

    local function setTimeout(timeout)
        state.timeout = timeout
    end

    local function setRebuildOnWrite(rebuild)
        state.rebuildOnWrite = (rebuild == true)
    end

    local api = {
        read = read,
        write = write,
        data = data,
        readValue = readValue,
        setValue = setValue,
        readComplete = readComplete,
        writeComplete = writeComplete,
        resetWriteStatus = resetWriteStatus,
        setCompleteHandler = setCompleteHandler,
        setErrorHandler = setErrorHandler,
        setUUID = setUUID,
        setTimeout = setTimeout,
        setRebuildOnWrite = setRebuildOnWrite,
        __rfReadStructure = readStructure,
        __rfWriteStructure = writeStructure
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

function core.createCustomAPI(spec)
    if type(spec) ~= "table" then
        error("api.createCustomAPI requires spec table")
    end
    if type(spec.name) ~= "string" or spec.name == "" then
        error("api.createCustomAPI requires spec.name")
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
    local readStructure = spec.readStructure or {}
    local writeStructure = spec.writeStructure or {}

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
        local parsed, parseErr

        if type(parser) == "function" then
            parsed, parseErr = parser(buf, mspHelper, state)
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

        if parsed.structure == nil then
            parsed.structure = readStructure
        end

        state.mspData = parsed

        local completeNow
        if type(spec.readCompleteCondition) == "function" then
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

    local function read(...)
        if not operationSupported(spec, "read") then
            return false, "read_not_supported"
        end

        if type(spec.customRead) == "function" then
            return spec.customRead(state, emitComplete, dispatchError, ...)
        end

        if spec.readCmd == nil then
            return false, "read_not_supported"
        end

        local payload = nil
        local readBuilder = spec.buildReadPayload
        if type(readBuilder) == "function" then
            local readErr
            payload, readErr = readBuilder(state.payloadData, state.mspData, mspHelper, state, ...)
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
            errorHandler = dispatchError,
            simulatorResponse = resolveSimulatorResponse(spec.simulatorResponseRead or EMPTY_SIM_RESPONSE, state, "read", ...),
            uuid = state.uuid,
            timeout = state.timeout,
            retryOnErrorReply = (spec.readRetryOnErrorReply == true),
            retryBackoff = spec.readRetryBackoff,
            completeOnErrorReplyAttempt = spec.readCompleteOnErrorReplyAttempt
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

        if readStructure ~= nil then
            message.structure = readStructure
        end

        return rfsuite.tasks.msp.mspQueue:add(message)
    end

    local function write(suppliedPayload, ...)
        if not operationSupported(spec, "write") then
            return false, "write_not_supported"
        end

        if type(spec.customWrite) == "function" then
            return spec.customWrite(suppliedPayload, state, emitComplete, dispatchError, ...)
        end

        if spec.writeCmd == nil then
            return false, "write_not_supported"
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
            if type(builder) == "function" then
                local buildErr
                payload, buildErr = builder(state.payloadData, state.mspData, mspHelper, state, ...)
                if payload == nil then
                    dispatchError(nil, buildErr or "build_payload_failed")
                    return false, buildErr or "build_payload_failed"
                end
            else
                payload = EMPTY_SIM_RESPONSE
            end
        end

        local message = {
            command = spec.writeCmd,
            apiname = spec.name,
            payload = payload,
            processReply = handleWriteReply,
            errorHandler = dispatchError,
            simulatorResponse = resolveSimulatorResponse(spec.simulatorResponseWrite or EMPTY_SIM_RESPONSE, state, "write", suppliedPayload, ...),
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
        if type(spec.readCompleteFn) == "function" then
            return spec.readCompleteFn(state)
        end
        local d = state.mspData
        return d ~= nil and d.buffer ~= nil and #d.buffer >= (spec.minBytes or 0)
    end

    local function writeComplete()
        return state.mspWriteComplete == true
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
        state.rebuildOnWrite = (rebuild == true)
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
        setRebuildOnWrite = setRebuildOnWrite,
        __rfReadStructure = readStructure,
        __rfWriteStructure = writeStructure
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

function core.createWriteOnlyAPI(spec)
    if type(spec) ~= "table" then
        error("api.createWriteOnlyAPI requires spec table")
    end
    if type(spec.name) ~= "string" or spec.name == "" then
        error("api.createWriteOnlyAPI requires spec.name")
    end
    if spec.writeCmd == nil then
        error("api.createWriteOnlyAPI requires spec.writeCmd")
    end

    local completeHandler = nil
    local errorHandler = nil
    local state = {
        mspWriteComplete = false,
        payloadData = {},
        timeout = nil,
        uuid = nil,
        rebuildOnWrite = (spec.initialRebuildOnWrite == true)
    }

    local function emitComplete(self, buf)
        if completeHandler then
            completeHandler(self, buf)
        end
    end

    local function dispatchError(self, errMsg)
        if errorHandler then
            errorHandler(self, errMsg)
        end
    end

    local function handleWriteReply(self, buf)
        state.mspWriteComplete = true
        emitComplete(self, buf)
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

    local function read()
        return false, "read_not_supported"
    end

    local function write(suppliedPayload, ...)
        local validateWrite = spec.validateWrite
        if type(validateWrite) == "function" then
            local ok, reason = validateWrite(suppliedPayload, state, ...)
            if ok == false then
                return false, reason or "write_validation_failed"
            end
        end

        local payload = suppliedPayload
        if payload == nil then
            local writeBuilder = spec.buildWritePayload
            if type(writeBuilder) == "function" then
                payload = writeBuilder(state.payloadData, nil, mspHelper, state, ...)
            elseif spec.writePayload ~= nil then
                payload = spec.writePayload
            else
                payload = EMPTY_SIM_RESPONSE
            end
        end

        local message = {
            command = spec.writeCmd,
            apiname = spec.name,
            payload = payload,
            processReply = handleWriteReply,
            errorHandler = dispatchError,
            simulatorResponse = spec.simulatorResponseWrite or EMPTY_SIM_RESPONSE,
            timeout = state.timeout,
            uuid = resolveWriteUUID(spec, state)
        }

        local writeUuidResolver = spec.resolveWriteUUID
        if type(writeUuidResolver) == "function" then
            message.uuid = writeUuidResolver(state, suppliedPayload, ...)
        end

        local timeoutResolver = spec.resolveWriteTimeout
        if type(timeoutResolver) == "function" then
            message.timeout = timeoutResolver(state, suppliedPayload, ...)
        end

        state.mspWriteComplete = false
        return rfsuite.tasks.msp.mspQueue:add(message)
    end

    local function data()
        return nil
    end

    local function readValue()
        return nil
    end

    local function setValue(fieldName, value)
        state.payloadData[fieldName] = value
    end

    local function readComplete()
        return false
    end

    local function writeComplete()
        return state.mspWriteComplete == true
    end

    local function resetWriteStatus()
        state.mspWriteComplete = false
    end

    local function setUUID(uuid)
        state.uuid = uuid
    end

    local function setTimeout(timeout)
        state.timeout = timeout
    end

    local function setRebuildOnWrite(rebuild)
        state.rebuildOnWrite = (rebuild == true)
    end

    local api = {
        read = read,
        write = write,
        data = data,
        readValue = readValue,
        setValue = setValue,
        readComplete = readComplete,
        writeComplete = writeComplete,
        resetWriteStatus = resetWriteStatus,
        setCompleteHandler = setCompleteHandler,
        setErrorHandler = setErrorHandler,
        setUUID = setUUID,
        setTimeout = setTimeout,
        setRebuildOnWrite = setRebuildOnWrite,
        __rfReadStructure = {},
        __rfWriteStructure = {}
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

return core
