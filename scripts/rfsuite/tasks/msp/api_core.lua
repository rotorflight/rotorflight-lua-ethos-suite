--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local core = {}

local mspHelper = rfsuite.tasks.msp.mspHelper
local utils = rfsuite.utils
local callback = rfsuite.tasks.callback

function core.scheduleWakeup(func)
    if callback and callback.now then
        callback.now(func)
    else
        utils.log("ERROR: callback.now() is missing!", "info")
    end
end

local function loadAPI(apiName)

    local apiFilePath = api_path .. apiName .. ".lua"

    if cached_file_exists(apiFilePath) then
        local apiModule = compiler.dofile(apiFilePath)

        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then

            apiModule.__apiName = apiName

            if apiModule.read then
                local originalRead = apiModule.read
                apiModule.read = function(...) return originalRead(...) end
            end

            if apiModule.write then
                local originalWrite = apiModule.write
                apiModule.write = function(...) return originalWrite(...) end
            end

            if apiModule.setValue then
                local originalSetValue = apiModule.setValue
                apiModule.setValue = function(...) return originalSetValue(...) end
            end

            if apiModule.readValue then
                local originalReadValue = apiModule.readValue
                apiModule.readValue = function(...) return originalReadValue(...) end
            end

            utils.log("Loaded API: " .. apiName, "debug")
            return apiModule
        else
            utils.log("Error: API file '" .. apiName .. "' does not contain valid read or write functions.", "debug")
        end
    else
        utils.log("Error: API file '" .. apiFilePath .. "' not found.", "debug")
    end
end

function core.clearFileExistsCache() core._fileExistsCache = {} end

function core.load(apiName)
    local api = loadAPI(apiName)
    if api == nil then utils.log("Unable to load " .. apiName, "debug") end
    return api
end

local TYPE_SIZES = {
    U8 = 1,
    S8 = 1,
    U16 = 2,
    S16 = 2,
    U24 = 3,
    S24 = 3,
    U32 = 4,
    S32 = 4,
    U40 = 5,
    S40 = 5,
    U48 = 6,
    S48 = 6,
    U56 = 7,
    S56 = 7,
    U64 = 8,
    S64 = 8,
    U72 = 9,
    S72 = 9,
    U80 = 10,
    S80 = 10,
    U88 = 11,
    S88 = 11,
    U96 = 12,
    S96 = 12,
    U104 = 13,
    S104 = 13,
    U112 = 14,
    S112 = 14,
    U120 = 15,
    S120 = 15,
    U128 = 16,
    S128 = 16
}
local function get_type_size(data_type)
    if data_type == nil then return TYPE_SIZES end
    return TYPE_SIZES[data_type] or 1
end

local function parseMSPChunk(buf, structure, state)
    local processedFields = 0
    local startIndex = state.index

    while state.index <= #structure and processedFields < 5 do
        local field = structure[state.index]
        state.index = state.index + 1

        if field.apiVersion and rfsuite.utils.apiVersionCompare("<", field.apiVersion) then goto continue end

        local readFunction = mspHelper["read" .. field.type]
        if not readFunction then
            utils.log("Error: No reader for type: " .. field.type, "debug")
            state.error = "Unknown type: " .. field.type
            return false
        end

        local data = readFunction(buf, field.byteorder or "little")
        state.parsedData[field.field] = data
        processedFields = processedFields + 1

        ::continue::
    end

    utils.log(string.format("Chunk processed - fields %d to %d", startIndex, state.index - 1), "debug")

    return state.index > #structure
end

function core.parseMSPData(API_NAME, buf, structure, processed, other, options)
    if type(options) == "function" then
        options = {chunked = true, completionCallback = options}
    elseif type(options) ~= "table" then
        options = {}
    end

    local chunked = options.chunked or false
    local fieldsPerTick = options.fieldsPerTick or 10
    local completionCallback = options.completionCallback

    if chunked then

        local state = {index = 1, parsedData = {}, positionmap = {}, processed = processed or {}, other = other or {}, currentByte = 1, fieldsPerTick = fieldsPerTick, completionCallback = completionCallback}

        local function processNextChunk()
            local processedFields = 0

            while state.index <= #structure and processedFields < fieldsPerTick do
                local field = structure[state.index]
                state.index = state.index + 1

                if field.apiVersion and rfsuite.utils.apiVersionCompare("<", field.apiVersion) then goto continue end

                local readFunction = mspHelper["read" .. field.type]
                if not readFunction then
                    utils.log("Error: No reader for type: " .. field.type, "debug")
                    return
                end

                local data = readFunction(buf, field.byteorder or "little")
                state.parsedData[field.field] = data

                local size = get_type_size(field.type)
                local startByte = state.currentByte
                local endByte = startByte + size - 1
                state.positionmap[field.field] = {start = startByte, size = size}
                state.currentByte = endByte + 1

                processedFields = processedFields + 1

                ::continue::
            end

            utils.log("[" .. API_NAME .. "] " .. string.format("Chunk processed - fields %d to %d", state.index - processedFields, state.index - 1), "debug")

            if state.index > #structure then
                if completionCallback and buf.offset then
                    completionCallback({parsed = state.parsedData, buffer = buf, structure = structure, positionmap = state.positionmap, processed = state.processed, other = state.other, receivedBytesCount = math.floor(buf.offset - 1)})
                else
                    utils.log("[" .. API_NAME .. "] Completion callback not provided or buffer offset not available", "info")
                    completionCallback({parsed = {state.parsedData}, buffer = {}, structure = structure, positionmap = state.positionmap, processed = state.processed, other = state.other, receivedBytesCount = 0})
                end
            else
                core.scheduleWakeup(processNextChunk)
            end
        end

        processNextChunk()
        return nil
    else

        local parsedData = {}
        buf.offset = 1

        local typeSizes = get_type_size()
        local position_map = {}
        local current_byte = 1

        for _, field in ipairs(structure) do
            if field.apiVersion and rfsuite.utils.apiVersionCompare("<", field.apiVersion) then goto continue end

            local readFunction = mspHelper["read" .. field.type]
            if not readFunction then
                utils.log("Error: No reader for type: " .. field.type, "debug")
                return nil
            end

            local data = readFunction(buf, field.byteorder or "little")
            parsedData[field.field] = data

            local size = typeSizes[field.type]
            local start_pos = current_byte
            local end_pos = start_pos + size - 1
            position_map[field.field] = {start = start_pos, size = size}

            current_byte = end_pos + 1

            ::continue::
        end

        if buf.offset <= #buf then
            local extraBytes = #buf - (buf.offset - 1)
            utils.log("[" .. API_NAME .. "] Unused bytes in buffer (" .. extraBytes .. " extra bytes)", "debug")
        elseif buf.offset > #buf + 1 then
            utils.log("[" .. API_NAME .. "] Offset exceeded buffer length (Offset: " .. buf.offset .. ", Buffer: " .. #buf .. ")", "debug")
        end

        completionCallback({parsed = parsedData, buffer = buf, structure = structure, positionmap = position_map, processed = processed, other = other, receivedBytesCount = math.floor(buf.offset - 1)})
    end
end

function core.calculateMinBytes(structure)

    local totalBytes = 0

    for _, param in ipairs(structure) do
        local insert_param = false

        if not param.apiVersion or rfsuite.utils.apiVersionCompare(">=", param.apiVersion) then insert_param = true end

        if insert_param and (param.mandatory ~= false) then totalBytes = totalBytes + get_type_size(param.type) end
    end

    return totalBytes
end

function core.filterByApiVersion(structure)
    local filteredStructure = {}

    for _, param in ipairs(structure) do
        local insert_param = false

        if not param.apiVersion or rfsuite.utils.apiVersionCompare(">=", param.apiVersion) then insert_param = true end

        if insert_param then table.insert(filteredStructure, param) end
    end

    return filteredStructure
end

function core.buildSimResponse(dataStructure, apiName)

    if system:getVersion().simulation == false then return nil end

    local response = {}

    for _, field in ipairs(dataStructure) do
        if field.simResponse then

            for _, value in ipairs(field.simResponse) do table.insert(response, value) end
        else

            local type_size = get_type_size(field.type)
            for i = 1, type_size do table.insert(response, 0) end
        end
    end

    return response
end

function core.createHandlers()

    local customCompleteHandler = nil
    local customErrorHandler = nil

    local function setCompleteHandler(handlerFunction)
        if type(handlerFunction) == "function" then
            customCompleteHandler = handlerFunction
        else
            error("setCompleteHandler expects a function")
        end
    end

    local function setErrorHandler(handlerFunction)
        if type(handlerFunction) == "function" then
            customErrorHandler = handlerFunction
        else
            error("setErrorHandler expects a function")
        end
    end

    local function getCompleteHandler() return customCompleteHandler end

    local function getErrorHandler() return customErrorHandler end

    return {setCompleteHandler = setCompleteHandler, setErrorHandler = setErrorHandler, getCompleteHandler = getCompleteHandler, getErrorHandler = getErrorHandler}
end

function core.buildWritePayload(apiname, payload, api_structure, noDelta)
    if not rfsuite.app.Page then
        utils.log("[buildWritePayload] No page context available", "info")
        return nil
    end

    local positionmap = rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.positionmap[apiname]
    local receivedBytes = rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.receivedBytes[apiname]
    local receivedBytesCount = rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.receivedBytesCount[apiname]

    local useDelta = positionmap and receivedBytes and receivedBytesCount

    if noDelta == true then useDelta = false end

    if useDelta then

        return core.buildDeltaPayload(apiname, payload, api_structure, positionmap, receivedBytes, receivedBytesCount)
    else

        return core.buildFullPayload(apiname, payload, api_structure)
    end
end

function core.buildDeltaPayload(apiname, payload, api_structure, positionmap, receivedBytes, receivedBytesCount)
    local byte_stream = {}

    for i = 1, receivedBytesCount or 0 do byte_stream[i] = receivedBytes and receivedBytes[i] or 0 end

    local editableFields = {}
    for idx, formField in ipairs(rfsuite.app.formFields) do
        local pageField = rfsuite.app.Page.fields[idx]
        if pageField and pageField.apikey then
            local key = pageField.apikey:match("([^%-]+)%-%>") or pageField.apikey
            editableFields[key] = true
        end
    end

    local actual_fields = {}
    if rfsuite.app.Page and rfsuite.app.Page.apidata then
        for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do

            if field.api and not field.apikey then
                local mspapi, apikey = string.match(field.api, "([^:]+):(.+)")

                for i, api in ipairs(rfsuite.app.Page.apidata.api) do
                    if api == mspapi then
                        mspapi = i
                        break
                    end
                end
                field.apikey = apikey
                field.mspapi = mspapi
                rfsuite.utils.log("[buildDeltaPayload] Converted api field '" .. field.api .. "' to mspapi=" .. tostring(mspapi) .. " apikey=" .. tostring(apikey), "info")
            end
            if not actual_fields[field.apikey] then actual_fields[field.apikey] = field end
        end
    end

    for _, field_def in ipairs(api_structure) do
        local field_name = field_def.field
        if not editableFields[field_name] then
            utils.log("[buildDeltaPayload] Skipping non-editable field: " .. field_name, "debug")
            goto continue
        end

        local actual_field = actual_fields[field_name]
        if actual_field then
            field_def.scale = field_def.scale or actual_field.scale
            field_def.mult = field_def.mult or actual_field.mult
            field_def.step = field_def.step or actual_field.step
            field_def.min = field_def.min or actual_field.min
            field_def.max = field_def.max or actual_field.max
        end

        local value = payload[field_name] or field_def.default or 0
        local scale = field_def.scale or 1
        value = math.floor(value * scale + 0.5)

        local writeFunction = mspHelper["write" .. field_def.type]
        if not writeFunction then error("Unknown type: " .. tostring(field_def.type)) end

        if positionmap[field_name] then
            local tmpStream = {}

            if field_def.byteorder then
                writeFunction(tmpStream, value, field_def.byteorder)
            else
                writeFunction(tmpStream, value)
            end
            local pm = positionmap[field_name]

            if type(pm) == "table" and pm.start and pm.size then
                local maxBytes = math.min(pm.size, #tmpStream)
                for i = 1, maxBytes do
                    local pos = pm.start + i - 1
                    if pos <= receivedBytesCount then byte_stream[pos] = tmpStream[i] end
                end
                utils.log(string.format("[buildDeltaPayload] Patched field '%s' into range start=%d size=%d", field_name, pm.start, pm.size), "debug")
            else
                for idx, pos in ipairs(pm) do if pos <= receivedBytesCount then byte_stream[pos] = tmpStream[idx] end end
                utils.log(string.format("[buildDeltaPayload] (legacy) Patched field '%s' into positions [%s]", field_name, table.concat(pm, ",")), "debug")
            end
        end

        ::continue::
    end

    return byte_stream
end

function core.buildFullPayload(apiname, payload, api_structure)
    local byte_stream = {}

    utils.log("[buildFullPayload] Clearing byte stream for full rebuild", "debug")

    local actual_fields = {}
    if rfsuite.app.Page and rfsuite.app.Page.apidata then for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do actual_fields[field.apikey] = field end end

    for _, field_def in ipairs(api_structure) do
        local field_name = field_def.field

        local actual_field = actual_fields[field_name]
        if actual_field then
            field_def.scale = field_def.scale or actual_field.scale
            field_def.mult = field_def.mult or actual_field.mult
            field_def.step = field_def.step or actual_field.step
            field_def.min = field_def.min or actual_field.min
            field_def.max = field_def.max or actual_field.max
            field_def.decimals = field_def.decimals or actual_field.decimals
        end

        local value = payload[field_name] or field_def.default or 0
        local scale = field_def.scale or 1

        if not actual_field and field_def.decimals then scale = scale / rfsuite.app.utils.decimalInc(field_def.decimals) end
        value = math.floor(value * scale + 0.5)

        local writeFunction = mspHelper["write" .. field_def.type]
        if not writeFunction then error("Unknown type: " .. tostring(field_def.type)) end

        local tmpStream = {}
        if field_def.byteorder then
            writeFunction(tmpStream, value, field_def.byteorder)
        else
            writeFunction(tmpStream, value)
        end

        for _, byte in ipairs(tmpStream) do table.insert(byte_stream, byte) end

        utils.log(string.format("[buildFullPayload] Full write for field '%s' with value %d", field_name, value), "debug")
    end

    return byte_stream
end

function core.prepareStructureData(structure)
    local filteredStructure = {}
    local minBytes = 0
    local simResponse = {}

    for _, param in ipairs(structure) do
        if param.apiVersion and rfsuite.utils.apiVersionCompare("<", param.apiVersion) then goto continue end

        table.insert(filteredStructure, param)

        if param.mandatory ~= false then minBytes = minBytes + get_type_size(param.type) end

        if param.simResponse then
            for _, value in ipairs(param.simResponse) do table.insert(simResponse, value) end
        else
            local typeSize = get_type_size(param.type)
            for i = 1, typeSize do table.insert(simResponse, 0) end
        end

        ::continue::
    end

    return filteredStructure, minBytes, simResponse
end

function core.filterByApiVersion(structure)
    local filtered, _, _ = core.prepareStructureData(structure)
    return filtered
end

function core.calculateMinBytes(structure)
    local _, minBytes, _ = core.prepareStructureData(structure)
    return minBytes
end

function core.buildSimResponse(structure)
    local _, _, simResponse = core.prepareStructureData(structure)
    return simResponse
end

return core
