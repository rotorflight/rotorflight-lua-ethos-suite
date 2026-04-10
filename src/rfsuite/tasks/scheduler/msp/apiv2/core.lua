--[[
  Copyright (C) 2026 Rotorflight Project
  GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local utils = rfsuite.utils
local type = type
local error = error
local ipairs = ipairs
local tostring = tostring
local loadfile = loadfile
local os_clock = os.clock

local core = {}

local mspHelper = rfsuite.tasks.msp.mspHelper
local isSim = (system and system.getVersion and system.getVersion().simulation) == true
local legacyCore = nil
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

local function getLegacyCore()
    if legacyCore then return legacyCore end

    local msp = rfsuite.tasks and rfsuite.tasks.msp
    if msp and msp.apicore then
        legacyCore = msp.apicore
        return legacyCore
    end

    local corePath = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/scheduler/msp/api/core.lua"
    local loaderFn = assert(loadfile(corePath))
    legacyCore = loaderFn()

    if msp and not msp.apicore then
        msp.apicore = legacyCore
    end

    return legacyCore
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
            error("Unknown MSP type in apiv2 structure: " .. tostring(typeName))
        end

        local fieldSize = TYPE_SIZES[typeName]
        if not fieldSize then
            error("Missing MSP size for apiv2 type: " .. tostring(typeName))
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

function core.prepareReadPlan(fieldSpec)
    local names = {}
    local readers = {}
    local minBytes = 0

    for i = 1, #fieldSpec, 2 do
        local fieldName = fieldSpec[i]
        local typeName = fieldSpec[i + 1]

        local reader = mspHelper["read" .. typeName]
        if not reader then
            error("Unknown MSP type in apiv2 plan: " .. tostring(typeName))
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

function core.simResponse(bytes)
    if not isSim then return nil end
    return bytes or {}
end

function core.createReadOnlyAPI(spec)
    if type(spec) ~= "table" then
        error("apiv2.createReadOnlyAPI requires spec table")
    end
    if type(spec.name) ~= "string" or spec.name == "" then
        error("apiv2.createReadOnlyAPI requires spec.name")
    end
    if spec.readCmd == nil then
        error("apiv2.createReadOnlyAPI requires spec.readCmd")
    end
    if type(spec.fields) ~= "table" then
        error("apiv2.createReadOnlyAPI requires spec.fields")
    end

    local fieldNames, fieldReaders, minBytes = core.prepareReadPlan(spec.fields)
    local completeHandler = nil
    local errorHandler = nil
    local state = {
        mspData = nil,
        timeout = nil,
        uuid = nil
    }

    local function processReply(self, buf)
        state.mspData = {
            parsed = core.parseReadPlan(buf, fieldNames, fieldReaders),
            structure = {},
            buffer = buf,
            positionmap = nil,
            other = nil,
            receivedBytesCount = #buf
        }
        if completeHandler then
            completeHandler(self, buf)
        end
    end

    local function onError(self, errMsg)
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

    local function read()
        if not operationSupported(spec, "read") then
            return false, "read_not_supported"
        end

        return rfsuite.tasks.msp.mspQueue:add({
            command = spec.readCmd,
            apiname = spec.name,
            minBytes = minBytes,
            processReply = processReply,
            errorHandler = onError,
            simulatorResponse = spec.simulatorResponseRead,
            timeout = state.timeout,
            uuid = state.uuid
        })
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

    return {
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
end

function core.createConfigAPI(spec)
    if type(spec) ~= "table" then
        error("apiv2.createConfigAPI requires spec table")
    end
    if type(spec.name) ~= "string" or spec.name == "" then
        error("apiv2.createConfigAPI requires spec.name")
    end
    if spec.readCmd == nil then
        error("apiv2.createConfigAPI requires spec.readCmd")
    end
    if spec.writeCmd == nil then
        error("apiv2.createConfigAPI requires spec.writeCmd")
    end
    if type(spec.fields) ~= "table" then
        error("apiv2.createConfigAPI requires spec.fields")
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
        state.mspData = {
            parsed = core.parseReadPlan(buf, fieldNames, fieldReaders),
            structure = readStructure,
            buffer = buf,
            positionmap = positionmap,
            other = nil,
            receivedBytesCount = #buf
        }
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

    local function read()
        if not operationSupported(spec, "read") then
            return false, "read_not_supported"
        end

        return rfsuite.tasks.msp.mspQueue:add({
            command = spec.readCmd,
            apiname = spec.name,
            minBytes = minBytes,
            processReply = handleReadReply,
            errorHandler = dispatchError,
            simulatorResponse = spec.simulatorResponseRead,
            timeout = state.timeout,
            uuid = state.uuid
        })
    end

    local function write(suppliedPayload)
        if not operationSupported(spec, "write") then
            return false, "write_not_supported"
        end

        local payload = suppliedPayload
        if payload == nil then
            payload = getLegacyCore().buildWritePayload(
                spec.name,
                state.payloadData,
                writeStructure,
                state.rebuildOnWrite == true
            )
        end

        return rfsuite.tasks.msp.mspQueue:add({
            command = spec.writeCmd,
            apiname = spec.name,
            payload = payload,
            processReply = handleWriteReply,
            errorHandler = dispatchError,
            simulatorResponse = spec.simulatorResponseWrite or EMPTY_SIM_RESPONSE,
            timeout = state.timeout,
            uuid = resolveWriteUUID(spec, state)
        })
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

    local exports = spec.exports
    if type(exports) == "table" then
        for name, value in pairs(exports) do
            api[name] = value
        end
    end

    return api
end

return core
