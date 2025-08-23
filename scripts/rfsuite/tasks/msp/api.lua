--
--[[

 * Copyright (C) Rotorflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]] --
local compiler = rfsuite.compiler

local apiLoader = {}

-- Cache table for file existence
apiLoader._fileExistsCache = apiLoader._fileExistsCache or {}

-- Define the API directory path based on the ethos version
local apidir = "SCRIPTS:/".. rfsuite.config.baseDir  .. "/tasks/msp/api/"
local api_path = apidir

-- track if this is the first load of the API
local firstLoadAPI = true

-- holders populated on first load
local mspHelper 
local utils 
local callback

-- helper: check & cache file existence
local function cached_file_exists(path)
  if apiLoader._fileExistsCache[path] == nil then
    apiLoader._fileExistsCache[path] = utils.file_exists(path)
  end
  return apiLoader._fileExistsCache[path]
end

-- New version using the global callback system
function apiLoader.scheduleWakeup(func)
    if callback and callback.now then
        callback.now(func)
    else
        utils.log("ERROR: callback.now() is missing!", "info")
    end
end


--[[
    Loads a Lua API module by its name, checks for the existence of the file, and wraps its functions.

    @param apiName (string) The name of the API to load.

    @return (table|nil) The loaded API module if successful, or nil if the file does not exist or is invalid.

    The function performs the following steps:
    1. Constructs the file path for the API module.
    2. Checks if the file exists using `utils.file_exists`.
    3. Loads the API module using `dofile`.
    4. Verifies that the module is a table and contains either a `read` or `write` function.
    5. Stores the API name inside the module as `__apiName`.
    6. Wraps the `read`, `write`, `setValue`, and `readValue` functions if they exist.
    7. Logs the successful loading of the API module.
    8. Returns the loaded API module.
    9. Logs an error if the file does not exist or the module is invalid.
--]]
local function loadAPI(apiName)

    local apiFilePath = api_path .. apiName .. ".lua"

    if firstLoadAPI then
        mspHelper = rfsuite.tasks.msp.mspHelper
        utils = rfsuite.utils
        callback = rfsuite.tasks.callback
        firstLoadAPI = false
    end    


    -- Check if file exists before trying to load it (cached)
    if cached_file_exists(apiFilePath) then
        local apiModule = compiler.dofile(apiFilePath) -- Load the Lua API file

        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then

            -- Store the API name inside the module
            apiModule.__apiName = apiName

            -- Wrap the read function
            if apiModule.read then
                local originalRead = apiModule.read
                apiModule.read = function(...)
                    return originalRead(...)
                end
            end

            -- Wrap the write function
            if apiModule.write then
                local originalWrite = apiModule.write
                apiModule.write = function(...) 
                    return originalWrite(...)
                end
            end

            -- Wrap the setValue function
            if apiModule.setValue then
                local originalSetValue = apiModule.setValue
                apiModule.setValue = function(...)
                    return originalSetValue(...)
                end
            end

            -- Wrap the readValue function
            if apiModule.readValue then
                local originalReadValue = apiModule.readValue
                apiModule.readValue = function(...)
                    return originalReadValue(...)
                end
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

-- clear the file-exists cache (call after adding/removing API files)
function apiLoader.clearFileExistsCache()
  apiLoader._fileExistsCache = {}
end

--[[
    Loads the specified API by name.
    
    @param apiName (string) - The name of the API to load.
    @return (table) - The loaded API table, or nil if the API could not be loaded.
]]
function apiLoader.load(apiName)
    local api = loadAPI(apiName)
    if api == nil then
        utils.log("Unable to load " .. apiName,"debug")
    end
    return api
end



--[[
    Function: get_type_size
    Description: Returns the size in bytes of the given data type.
    Parameters:
        data_type (string) - The data type for which the size is to be determined. 
                             Supported types are U8, S8, U16, S16, U24, S24, U32, S32, 
                             U40, S40, U48, S48, U56, S56, U64, S64, U72, S72, U80, 
                             S80, U88, S88, U96, S96, U104, S104, U112, S112, U120, 
                             S120, U128, S128.
    Returns:
        number - The size in bytes of the given data type. Defaults to 1 if the data type is unknown.
]]
local TYPE_SIZES = {
  U8=1,S8=1, U16=2,S16=2, U24=3,S24=3, U32=4,S32=4, U40=5,S40=5, U48=6,S48=6,
  U56=7,S56=7, U64=8,S64=8, U72=9,S72=9, U80=10,S80=10, U88=11,S88=11,
  U96=12,S96=12, U104=13,S104=13, U112=14,S112=14, U120=15,S120=15, U128=16,S128=16
}
function get_type_size(data_type)
  if data_type == nil then return TYPE_SIZES end
  return TYPE_SIZES[data_type] or 1
end



--[[
    Parses a chunk of MSP (Multiwii Serial Protocol) data according to the provided structure and state.
    
    @param buf (string): The buffer containing the MSP data to be parsed.
    @param structure (table): A table defining the structure of the MSP data. Each entry in the table should be a field definition.
    @param state (table): A table representing the current state of the parser. It should contain:
        - index (number): The current index in the structure table.
        - parsedData (table): A table to store the parsed data fields.
        - error (string, optional): An error message if an error occurs during parsing.
    
    @return (boolean): Returns true if all fields in the structure have been processed, false otherwise.
    
    The function processes up to 5 fields per call (wakeup) to allow for chunked parsing. It logs the range of fields processed in each call.
    If a field has an `apiVersion` and the current API version is less than the field's `apiVersion`, the field is skipped.
    If a field type does not have a corresponding read function, an error is logged and the parsing is halted.
]]
local function parseMSPChunk(buf, structure, state)
    local processedFields = 0
    local startIndex = state.index

    while state.index <= #structure and processedFields < 5 do  -- Process 5 fields per wakeup
        local field = structure[state.index]
        state.index = state.index + 1

        if field.apiVersion and rfsuite.utils.apiVersionCompare("<", field.apiVersion) then
            goto continue
        end

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

--[[
    Parses MSP data from a buffer according to a given structure.

    @param buf (table) - The buffer containing the MSP data.
    @param structure (table) - The structure defining the fields to be parsed.
    @param processed (table) - Optional. A table to store processed data.
    @param other (table) - Optional. A table to store additional data.
    @param options (table|function) - Optional. A table of options or a completion callback function.
        @field chunked (boolean) - If true, processes data in chunks asynchronously.
        @field fieldsPerTick (number) - Number of fields to process per tick in chunked mode.
        @field completionCallback (function) - Callback function to be called upon completion in chunked mode.

    @return (table|nil) - Returns a table with parsed data, buffer, structure, position map, processed data, other data, and received bytes count in blocking mode.
                          Returns nil in chunked mode.
--]]
function apiLoader.parseMSPData(buf, structure, processed, other, options)
    if type(options) == "function" then
        options = {chunked = true, completionCallback = options}
    elseif type(options) ~= "table" then
        options = {}
    end

    local chunked = options.chunked or false
    local fieldsPerTick = options.fieldsPerTick or 10
    local completionCallback = options.completionCallback

    if chunked then
        -- Chunked async mode
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

                if field.apiVersion and rfsuite.utils.apiVersionCompare("<", field.apiVersion) then
                    goto continue
                end

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
                state.positionmap[field.field] = { start = startByte, size = size }
                state.currentByte = endByte + 1

                processedFields = processedFields + 1

                ::continue::
            end

            utils.log(string.format("Chunk processed - fields %d to %d", 
                state.index - processedFields, state.index - 1), "debug")

            if state.index > #structure then
                if completionCallback and buf.offset then
                    completionCallback({
                        parsed = state.parsedData,
                        buffer = buf,
                        structure = structure,
                        positionmap = state.positionmap,
                        processed = state.processed,
                        other = state.other,
                        receivedBytesCount = math.floor(buf.offset - 1)
                    })
                else
                    utils.log("Completion callback not provided or buffer offset not available", "info")
                    completionCallback({
                        parsed = {state.parsedData},
                        buffer = {},
                        structure = structure,
                        positionmap = state.positionmap,
                        processed = state.processed,
                        other = state.other,
                        receivedBytesCount = 0
                    })
                end
            else
                apiLoader.scheduleWakeup(processNextChunk)
            end
        end

        processNextChunk()
        return nil
    else
        -- Blocking mode (sync)
        local parsedData = {}
        buf.offset = 1

        local typeSizes = get_type_size()
        local position_map = {}
        local current_byte = 1

        for _, field in ipairs(structure) do
            if field.apiVersion and rfsuite.utils.apiVersionCompare("<", field.apiVersion) then
                goto continue
            end

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
            position_map[field.field] = { start = start_pos, size = size }

            current_byte = end_pos + 1

            ::continue::
        end

        if buf.offset <= #buf then
            local extraBytes = #buf - (buf.offset - 1)
            utils.log("Unused bytes in buffer (" .. extraBytes .. " extra bytes)", "debug")
        elseif buf.offset > #buf + 1 then
            utils.log("Offset exceeded buffer length (Offset: " .. buf.offset .. ", Buffer: " .. #buf .. ")", "debug")
        end

        return {
            parsed = parsedData,
            buffer = buf,
            structure = structure,
            positionmap = position_map,
            processed = processed,
            other = other,
            receivedBytesCount = math.floor(buf.offset - 1)
        }
    end
end



--[[
    Calculates the minimum number of bytes required for a given structure.

    @param structure (table): A table containing parameter definitions. Each parameter is a table with the following fields:
        - type (string): The data type of the parameter.
        - apiVersion (number, optional): The minimum API version required for this parameter.
        - mandatory (boolean, optional): Whether the parameter is mandatory. Defaults to true if not specified.

    @return (number): The total number of bytes required for the structure.
]]
function apiLoader.calculateMinBytes(structure)

    local totalBytes = 0

    for _, param in ipairs(structure) do
        local insert_param = false
    
        -- API version check logic
        if not param.apiVersion or rfsuite.utils.apiVersionCompare(">=", param.apiVersion) then
            insert_param = true
        end
    
        -- Mandatory check
        if insert_param and (param.mandatory ~= false) then
            totalBytes = totalBytes + get_type_size(param.type)
        end
    end

    return totalBytes
end


--[[
    Filters a given structure based on the API version.

    @param structure (table): The structure to be filtered. Each element in the structure
                              should be a table that may contain an 'apiVersion' field.

    @return (table): A new table containing only the elements from the input structure
                     that meet the API version criteria.
]]
function apiLoader.filterByApiVersion(structure)
    local filteredStructure = {}

    for _, param in ipairs(structure) do
        local insert_param = false

        -- API version check logic
        if not param.apiVersion or rfsuite.utils.apiVersionCompare(">=", param.apiVersion) then
            insert_param = true
        end

        if insert_param then
            table.insert(filteredStructure, param)
        end
    end

    return filteredStructure
end

--[[
    Builds a simulated response based on the provided data structure.

    This function generates a response table for simulation purposes. It checks if the system is in simulation mode,
    and if so, it constructs the response based on the `simResponse` field of each element in the `dataStructure`.
    If `simResponse` is not provided for a field, it inserts default values based on the field's type size.

    @param dataStructure (table): A table containing the data structure with fields that may include `simResponse`.

    @return response (table or nil): A table containing the simulated response values, or nil if not in simulation mode.
]]
function apiLoader.buildSimResponse(dataStructure, apiName)

    if system:getVersion().simulation == false then
        return nil
    end

    -- Fallback to building from dataStructure if file is invalid or missing
    local response = {}

    for _, field in ipairs(dataStructure) do
        if field.simResponse then
            -- Append all values in simResponse to the response table
            for _, value in ipairs(field.simResponse) do
                table.insert(response, value)
            end
        else
            -- If simResponse is nil, insert default values based on the field's type size
            local type_size = get_type_size(field.type)
            for i = 1, type_size do
                table.insert(response, 0)
            end
        end
    end

    return response
end


--[[
    Creates a new instance of handlers for complete and error events.
    
    Functions:
    - setCompleteHandler(handlerFunction): Sets the custom complete handler. Expects a function as an argument.
    - setErrorHandler(handlerFunction): Sets the custom error handler. Expects a function as an argument.
    - getCompleteHandler(): Returns the current custom complete handler.
    - getErrorHandler(): Returns the current custom error handler.
    
    Returns:
    A table with the following functions:
    - setCompleteHandler
    - setErrorHandler
    - getCompleteHandler
    - getErrorHandler
]]
function apiLoader.createHandlers()
    -- Instance-specific storage
    local customCompleteHandler = nil
    local customErrorHandler = nil

    -- Function to set the Complete handler
    local function setCompleteHandler(handlerFunction)
        if type(handlerFunction) == "function" then
            customCompleteHandler = handlerFunction
        else
            error("setCompleteHandler expects a function")
        end
    end

    -- Function to set the Error handler
    local function setErrorHandler(handlerFunction)
        if type(handlerFunction) == "function" then
            customErrorHandler = handlerFunction
        else
            error("setErrorHandler expects a function")
        end
    end

    -- Function to get handlers safely
    local function getCompleteHandler()
        return customCompleteHandler
    end

    local function getErrorHandler()
        return customErrorHandler
    end

    -- Return an instance with functions that operate on separate data
    return {setCompleteHandler = setCompleteHandler, setErrorHandler = setErrorHandler, getCompleteHandler = getCompleteHandler, getErrorHandler = getErrorHandler}
end


--[[
    Builds the payload for writing data to the specified API.

    @param apiname (string) - The name of the API.
    @param payload (table) - The data to be written.
    @param api_structure (table) - The structure of the API.
    @param noDelta (boolean) - Optional flag to disable delta updates. If true, a full rebuild will be used.

    @return (table) - The payload to be written to the API.

    The function determines whether to use delta updates or a full rebuild based on the presence of positionmap,
    receivedBytes, and receivedBytesCount for the given API name. If delta updates are available and noDelta is not set,
    it will use delta updates. Otherwise, it will perform a full rebuild of the payload.
--]]
function apiLoader.buildWritePayload(apiname, payload, api_structure, noDelta)
    if not rfsuite.app.Page then
        utils.log("[buildWritePayload] No page context available", "info")
        return nil
    end

    local positionmap = rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.positionmap[apiname]
    local receivedBytes = rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.receivedBytes[apiname]
    local receivedBytesCount = rfsuite.app.Page.apidata and rfsuite.app.Page.apidata.receivedBytesCount[apiname]

    local useDelta = positionmap and receivedBytes and receivedBytesCount

    -- Override delta usage if noDelta is set
    if noDelta == true then
        useDelta = false
    end

    if useDelta then
        utils.log("[buildWritePayload] Using delta updates for " .. apiname, "info")
        return apiLoader.buildDeltaPayload(apiname, payload, api_structure, positionmap, receivedBytes, receivedBytesCount)
    else
        utils.log("[buildWritePayload] Using full rebuild for " .. apiname, "info")
        return apiLoader.buildFullPayload(apiname, payload, api_structure)
    end
end

--[[
    Builds a delta payload for the given API name and payload.

    @param apiname (string) The name of the API.
    @param payload (table) The payload data to be processed.
    @param api_structure (table) The structure of the API fields.
    @param positionmap (table) A map of field names to their positions in the byte stream.
    @param receivedBytes (table) The previously received bytes.
    @param receivedBytesCount (number) The count of previously received bytes.

    @return (table) The byte stream representing the delta payload.

    The function performs the following steps:
    1. Initializes the byte stream with the last known bytes.
    2. Identifies editable fields from the form fields.
    3. Iterates over the API structure and processes each field:
        - Skips non-editable fields.
        - Retrieves the value from the payload or uses the default value.
        - Scales the value if necessary.
        - Writes the value to the byte stream using the appropriate write function.
        - Patches existing data in the byte stream for delta updates.
--]]
function apiLoader.buildDeltaPayload(apiname, payload, api_structure, positionmap, receivedBytes, receivedBytesCount)
    local byte_stream = {}

    -- Start with a copy of the last known bytes
    for i = 1, receivedBytesCount or 0 do
        byte_stream[i] = receivedBytes and receivedBytes[i] or 0
    end

    -- Get editable fields
    local editableFields = {}
    for idx, formField in ipairs(rfsuite.app.formFields) do
        local pageField = rfsuite.app.Page.fields[idx]
        if pageField and pageField.apikey then
            local key = pageField.apikey:match("([^%-]+)%-%>") or pageField.apikey
            editableFields[key] = true
        end
    end

    -- Extract parameters from actual.lua
    local actual_fields = {}
    if rfsuite.app.Page and rfsuite.app.Page.apidata then
        for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do
            if not actual_fields[field.apikey] then -- we check this because its possible a field may not be there is mspgt or msplt is used on page.
                actual_fields[field.apikey] = field
            end
        end
    end 


    -- Iterate over the API structure and apply updates
    for _, field_def in ipairs(api_structure) do
        local field_name = field_def.field
        if not editableFields[field_name] then
            utils.log("[buildDeltaPayload] Skipping non-editable field: " .. field_name, "debug")
            goto continue
        end

        -- Merge missing parameters from rendered page
        local actual_field = actual_fields[field_name]
        if actual_field then
            field_def.scale = field_def.scale or actual_field.scale
            field_def.mult = field_def.mult or actual_field.mult
            field_def.step = field_def.step or actual_field.step
            field_def.min = field_def.min or actual_field.min
            field_def.max = field_def.max or actual_field.max
        end

        -- Process value with scale
        local value = payload[field_name] or field_def.default or 0
        local scale = field_def.scale or 1
        value = math.floor(value * scale + 0.5)

        -- Determine write function
        local writeFunction = mspHelper["write" .. field_def.type]
        if not writeFunction then
            error("Unknown type: " .. tostring(field_def.type))
        end

        -- Handle delta update (patching existing data)
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
                    if pos <= receivedBytesCount then
                        byte_stream[pos] = tmpStream[i]
                    end
                end
                utils.log(string.format(
                    "[buildDeltaPayload] Patched field '%s' into range start=%d size=%d",
                    field_name, pm.start, pm.size
                ), "debug")
            else
                for idx, pos in ipairs(pm) do
                    if pos <= receivedBytesCount then
                        byte_stream[pos] = tmpStream[idx]
                    end
                end
                utils.log(string.format(
                    "[buildDeltaPayload] (legacy) Patched field '%s' into positions [%s]",
                    field_name, table.concat(pm, ",")
                ), "debug")
            end
        end

        ::continue::
    end

    return byte_stream
end


--[[
    Builds a full payload byte stream based on the provided API structure.

    @param apiname (string) - The name of the API being used.
    @param payload (table) - A table containing the data to be converted into a byte stream.
    @param api_structure (table) - A table defining the structure of the API, including field names, types, byte order, and scaling factors.

    @return (table) - A byte stream representing the full payload.

    The function performs the following steps:
    1. Clears the byte stream for a full rebuild.
    2. Iterates over each field definition in the API structure.
    3. Retrieves the value for each field from the payload, or uses the default value if not provided.
    4. Scales the value if a scale factor is defined.
    5. Converts the value to the appropriate byte representation using the corresponding write function.
    6. Appends the byte representation to the byte stream.
    7. Logs the process for each field.

    @throws (error) - If an unknown type is encountered in the field definition.
]]
function apiLoader.buildFullPayload(apiname, payload, api_structure)
    local byte_stream = {}

    utils.log("[buildFullPayload] Clearing byte stream for full rebuild", "debug")

    -- Extract parameters from actual.lua
    local actual_fields = {}
    if rfsuite.app.Page and rfsuite.app.Page.apidata then
        for _, field in ipairs(rfsuite.app.Page.apidata.formdata.fields) do
            actual_fields[field.apikey] = field
        end
    end

    for _, field_def in ipairs(api_structure) do
        local field_name = field_def.field

        -- Merge missing parameters from rendered page
        local actual_field = actual_fields[field_name]
        if actual_field then
            field_def.scale = field_def.scale or actual_field.scale
            field_def.mult = field_def.mult or actual_field.mult
            field_def.step = field_def.step or actual_field.step
            field_def.min = field_def.min or actual_field.min
            field_def.max = field_def.max or actual_field.max
            field_def.decimals = field_def.decimals or actual_field.decimals
        end

        -- Process value with scale
        local value = payload[field_name] or field_def.default or 0
        local scale = field_def.scale or 1
        
        -- scale is an odd one and needs to be handled differently
        if not actual_field and field_def.decimals then
            scale = scale / rfsuite.app.utils.decimalInc(field_def.decimals)
        end
        value = math.floor(value * scale + 0.5)

        -- Determine write function
        local writeFunction = mspHelper["write" .. field_def.type]
        if not writeFunction then
            error("Unknown type: " .. tostring(field_def.type))
        end

        -- Write the value to the byte stream
        local tmpStream = {}
        if field_def.byteorder then
            writeFunction(tmpStream, value, field_def.byteorder)
        else
            writeFunction(tmpStream, value)
        end

        for _, byte in ipairs(tmpStream) do
            table.insert(byte_stream, byte)
        end

        utils.log(string.format(
            "[buildFullPayload] Full write for field '%s' with value %d",
            field_name, value
        ), "debug")
    end

    return byte_stream
end

-- New function to process structure in one pass
function apiLoader.prepareStructureData(structure)
    local filteredStructure = {}
    local minBytes = 0
    local simResponse = {}

    for _, param in ipairs(structure) do
        if param.apiVersion and rfsuite.utils.apiVersionCompare("<", param.apiVersion) then
            goto continue
        end

        table.insert(filteredStructure, param)

        if param.mandatory ~= false then
            minBytes = minBytes + get_type_size(param.type)
        end

        if param.simResponse then
            for _, value in ipairs(param.simResponse) do
                table.insert(simResponse, value)
            end
        else
            local typeSize = get_type_size(param.type)
            for i = 1, typeSize do
                table.insert(simResponse, 0)
            end
        end

        ::continue::
    end

    return filteredStructure, minBytes, simResponse
end

-- Backward compatible stubs
function apiLoader.filterByApiVersion(structure)
    local filtered, _, _ = apiLoader.prepareStructureData(structure)
    return filtered
end

function apiLoader.calculateMinBytes(structure)
    local _, minBytes, _ = apiLoader.prepareStructureData(structure)
    return minBytes
end

function apiLoader.buildSimResponse(structure)
    local _, _, simResponse = apiLoader.prepareStructureData(structure)
    return simResponse
end

return apiLoader
