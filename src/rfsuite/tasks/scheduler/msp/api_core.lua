--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")


-- Optimized locals to reduce global/table lookups
local utils = rfsuite.utils
local math_min = math.min
local core = {}

local mspHelper = rfsuite.tasks.msp.mspHelper
local callback  = rfsuite.tasks.callback

-- Schedule a callback to run next wakeup
function core.scheduleWakeup(func)
    if callback and callback.now then
        callback.now(func)
    else
        utils.log("ERROR: callback.now() is missing!", "info")
    end
end

------------------------------------------------------------
-- Internal API loader (rarely used directly)
------------------------------------------------------------

local function loadAPI(apiName)
    local apiFilePath = api_path .. apiName .. ".lua"

    if cached_file_exists(apiFilePath) then
        local apiModule = dofile(apiFilePath)

        -- Valid API must implement read/write
        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then

            apiModule.__apiName = apiName

            -- Pass-through wrapper functions
            if apiModule.read then
                local original = apiModule.read
                apiModule.read = function(...) return original(...) end
            end

            if apiModule.write then
                local original = apiModule.write
                apiModule.write = function(...) return original(...) end
            end

            if apiModule.setValue then
                local original = apiModule.setValue
                apiModule.setValue = function(...) return original(...) end
            end

            if apiModule.readValue then
                local original = apiModule.readValue
                apiModule.readValue = function(...) return original(...) end
            end

            utils.log("Loaded API: " .. apiName, "debug")
            return apiModule
        else
            utils.log("Error: API '" .. apiName .. "' missing read/write", "debug")
        end
    else
        utils.log("Error: API file '" .. apiFilePath .. "' not found.", "debug")
    end
end

core._fileExistsCache = {}

function core.clearFileExistsCache() core._fileExistsCache = {} end

-- Load an API without caching layer (caller handles caching)
function core.load(apiName)
    local api = loadAPI(apiName)
    if api == nil then utils.log("Unable to load " .. apiName, "debug") end
    return api
end

------------------------------------------------------------
-- Type size lookup
------------------------------------------------------------

local TYPE_SIZES = {
    U8=1, S8=1, U16=2, S16=2, U24=3, S24=3, U32=4, S32=4,
    U40=5, S40=5, U48=6, S48=6, U56=7, S56=7, U64=8, S64=8,
    U72=9, S72=9, U80=10, S80=10, U88=11, S88=11,
    U96=12, S96=12, U104=13, S104=13, U112=14, S112=14,
    U120=15, S120=15, U128=16, S128=16
}

local function get_type_size(data_type)
    if data_type == nil then return TYPE_SIZES end
    return TYPE_SIZES[data_type] or 1
end

-- Full MSP data parsing (supports chunked mode)
------------------------------------------------------------

function core.parseMSPData(API_NAME, buf, structure, processed, other, options)
    -- Normalize options
    if type(options) == "function" then
        options = {chunked = true, completionCallback = options}
    elseif type(options) ~= "table" then
        options = {}
    end

    local chunked            = options.chunked or false
    local fieldsPerTick      = options.fieldsPerTick or 10
    local completionCallback = options.completionCallback

    ------------------------------------------------------------
    -- Chunked parsing (spread across wakeups)
    ------------------------------------------------------------
    if chunked then
        local state = {
            index = 1,
            parsedData = {},
            positionmap = {},
            processed = processed or {},
            other = other or {},
            currentByte = 1,
            fieldsPerTick = fieldsPerTick,
            completionCallback = completionCallback
        }

        local function processNextChunk()
            local processedFields = 0

            while state.index <= #structure and processedFields < fieldsPerTick do
                local field = structure[state.index]
                state.index = state.index + 1

                if field.apiVersion and utils.apiVersionCompare("<", field.apiVersion) then goto continue end

                local readFunction = mspHelper["read" .. field.type]
                if not readFunction then
                    utils.log("Error: Unknown type " .. field.type, "debug")
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

            utils.log("[" .. API_NAME .. "] Processed chunk", "debug")

            if state.index > #structure then
                -- All fields parsed
                local final = {
                    parsed = state.parsedData,
                    buffer = buf,
                    structure = structure,
                    positionmap = state.positionmap,
                    processed = state.processed,
                    other = state.other,
                    receivedBytesCount = math.floor((buf.offset or 1) - 1)
                }
                if completionCallback then completionCallback(final) end
            else
                core.scheduleWakeup(processNextChunk)
            end
        end

        processNextChunk()
        return nil
    end

    ------------------------------------------------------------
    -- Non-chunked: parse everything now
    ------------------------------------------------------------

    local parsedData = {}
    buf.offset = 1

    local typeSizes = get_type_size()
    local position_map = {}
    local current_byte = 1

    for _, field in ipairs(structure) do
        if field.apiVersion and utils.apiVersionCompare("<", field.apiVersion) then goto continue end

        local readFunction = mspHelper["read" .. field.type]
        if not readFunction then
            utils.log("Error: Unknown type " .. field.type, "debug")
            return nil
        end

        local data = readFunction(buf, field.byteorder or "little")
        parsedData[field.field] = data

        local size = typeSizes[field.type]
        position_map[field.field] = {start = current_byte, size = size}
        current_byte = current_byte + size

        ::continue::
    end

    local final = {
        parsed = parsedData,
        buffer = buf,
        structure = structure,
        positionmap = position_map,
        processed = processed,
        other = other,
        receivedBytesCount = math.floor(buf.offset - 1)
    }

    completionCallback(final)
end

------------------------------------------------------------
-- Structure analysis helpers
------------------------------------------------------------

-- Completion / error handler helpers
------------------------------------------------------------

function core.createHandlers()
    local completeHandler = nil
    local privateErrorHandler = nil

    return {
        setCompleteHandler = function(fn)
            if type(fn) == "function" then completeHandler = fn
            else error("Complete handler requires function") end
        end,
        setErrorHandler = function(fn)
            if type(fn) == "function" then privateErrorHandler = fn
            else error("Error handler requires function") end
        end,
        getCompleteHandler = function() return completeHandler end,
        getErrorHandler = function() return privateErrorHandler end
    }
end

------------------------------------------------------------
-- Payload builders
------------------------------------------------------------

-- Choose full vs delta payload based on available previous data
function core.buildWritePayload(apiname, payload, api_structure, noDelta)
    if not rfsuite.app.Page then
        utils.log("[buildWritePayload] No page context", "info")
        -- tasks have no UI context; always build a full payload
        return core.buildFullPayload(apiname, payload, api_structure)        
    end

    local positionmap       = rfsuite.tasks.msp.api.apidata.positionmap and rfsuite.tasks.msp.api.apidata.positionmap[apiname]
    local receivedBytes     = rfsuite.tasks.msp.api.apidata.receivedBytes and rfsuite.tasks.msp.api.apidata.receivedBytes[apiname]
    local receivedBytesCount= rfsuite.tasks.msp.api.apidata.receivedBytesCount and rfsuite.tasks.msp.api.apidata.receivedBytesCount[apiname]

    local useDelta = positionmap and receivedBytes and receivedBytesCount
    if noDelta == true then useDelta = false end

    if useDelta then
        return core.buildDeltaPayload(apiname, payload, api_structure, positionmap, receivedBytes, receivedBytesCount)
    else
        return core.buildFullPayload(apiname, payload, api_structure)
    end
end

-- Build delta payload (patch only changed bytes)
function core.buildDeltaPayload(apiname, payload, api_structure, positionmap, receivedBytes, receivedBytesCount)
    local byte_stream = {}

    -- Clone previous data for patching
    for i = 1, receivedBytesCount or 0 do
        byte_stream[i] = receivedBytes and receivedBytes[i] or 0
    end

    -- Determine which fields are editable
    local editableFields = {}
    for idx, formField in ipairs(rfsuite.app.formFields) do
        local pageField = rfsuite.app.Page.apidata.formdata.fields[idx]
        if pageField and pageField.apikey then
            local key = pageField.apikey:match("([^%-]+)%-%>") or pageField.apikey
            editableFields[key] = true
        end
    end

    -- Build lookup of actual UI fields
    local actual_fields = {}
    if rfsuite.app.Page and rfsuite.app.Page.apidata then
        for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do
            if field.api and not field.apikey then
                local mspapi, apikey = string.match(field.api, "([^:]+):(.+)")
                for i, api in ipairs(rfsuite.app.Page.apidata.api) do
                    if api == mspapi then mspapi = i; break end
                end
                field.apikey = apikey
                field.mspapi = mspapi
                utils.log("[buildDeltaPayload] Converted API field", "info")
            end

            if field.apikey then actual_fields[field.apikey] = field end
        end
    end

    -- Patch only changed values
    for _, field_def in ipairs(api_structure) do
        local name = field_def.field

        -- Skip non-editable
        if not editableFields[name] then goto continue end

        -- Sync field constraints if UI-side defines them
        local actual_field = actual_fields[name]
        if actual_field then
            field_def.scale  = field_def.scale  or actual_field.scale
            field_def.mult   = field_def.mult   or actual_field.mult
            field_def.step   = field_def.step   or actual_field.step
            field_def.min    = field_def.min    or actual_field.min
            field_def.max    = field_def.max    or actual_field.max
        end

        -- Apply scale and quantization
        local value = payload[name] or field_def.default or 0
        local scale = field_def.scale or 1
        value = math.floor(value * scale + 0.5)

        -- Write into temporary buffer
        local writeFunction = mspHelper["write" .. field_def.type]
        if not writeFunction then error("Unknown type " .. field_def.type) end

        local tmp = {}
        if field_def.byteorder then writeFunction(tmp, value, field_def.byteorder)
        else writeFunction(tmp, value) end

        -- Patch into correct positions
        local pm = positionmap[name]
        if type(pm) == "table" and pm.start and pm.size then
            local maxBytes = math_min(pm.size, #tmp)
            for i = 1, maxBytes do
                local pos = pm.start + i - 1
                if pos <= receivedBytesCount then byte_stream[pos] = tmp[i] end
            end
        elseif pm then
            for idx, pos in ipairs(pm) do
                if pos <= receivedBytesCount then byte_stream[pos] = tmp[idx] end
            end
        end

        ::continue::
    end

    return byte_stream
end

-- Build complete payload from scratch
function core.buildFullPayload(apiname, payload, api_structure)
    local byte_stream = {}
    utils.log("[buildFullPayload] Rebuilding entire payload", "debug")

    -- Lookup UI field definitions if available
    local actual_fields = {}
    if rfsuite.app.Page and rfsuite.app.Page.apidata then
        for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do
            if field.apikey then
                actual_fields[field.apikey] = field
            end
        end
    end

    for _, field_def in ipairs(api_structure) do
        local name = field_def.field

        -- Sync UI metadata
        local actual = actual_fields[name]
        if actual then
            field_def.scale    = field_def.scale    or actual.scale
            field_def.mult     = field_def.mult     or actual.mult
            field_def.step     = field_def.step     or actual.step
            field_def.min      = field_def.min      or actual.min
            field_def.max      = field_def.max      or actual.max
            field_def.decimals = field_def.decimals or actual.decimals
        end

        local value = payload[name] or field_def.default or 0
        local scale = field_def.scale or 1

        -- Decimal-handling fallback
        if not actual and field_def.decimals then
            scale = scale / rfsuite.app.utils.decimalInc(field_def.decimals)
        end

        value = math.floor(value * scale + 0.5)

        local writeFunction = mspHelper["write" .. field_def.type]
        if not writeFunction then error("Unknown type " .. field_def.type) end

        local tmp = {}
        if field_def.byteorder then writeFunction(tmp, value, field_def.byteorder)
        else writeFunction(tmp, value) end

        for _, b in ipairs(tmp) do table.insert(byte_stream, b) end

        utils.log(string.format("[buildFullPayload] Wrote field '%s' = %d", name, value), "debug")
    end

    return byte_stream
end

------------------------------------------------------------
-- Structure preparation (filter + minBytes + sim response)
------------------------------------------------------------

function core.prepareStructureData(structure)
    local filtered = {}
    local minBytes = 0
    local simResponse = {}

    for _, param in ipairs(structure) do
        -- Skip if API version doesn't match
        if param.apiVersion and utils.apiVersionCompare("<", param.apiVersion) then goto continue end

        table.insert(filtered, param)

        if param.mandatory ~= false then
            minBytes = minBytes + get_type_size(param.type)
        end

        if param.simResponse then
            for _, v in ipairs(param.simResponse) do table.insert(simResponse, v) end
        else
            for i = 1, get_type_size(param.type) do table.insert(simResponse, 0) end
        end

        ::continue::
    end

    return filtered, minBytes, simResponse
end

function core.filterByApiVersion(structure)
    local filtered = core.prepareStructureData(structure)
    return filtered
end

function core.calculateMinBytes(structure)
    local _, minBytes = core.prepareStructureData(structure)
    return minBytes
end

function core.buildSimResponse(structure)
    local _, _, simResponse = core.prepareStructureData(structure)
    return simResponse
end

return core
