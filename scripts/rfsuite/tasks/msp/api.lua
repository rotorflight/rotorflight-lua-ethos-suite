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
local apiLoader = {}

-- Cache to store loaded API modules
local apiCache = {}

-- Define the API directory path based on the ethos version
local apidir = "tasks/msp/api/"
local api_path = apidir


--[[
    Loads and returns an API module by its name, with caching and logging functionality.
    
    @param apiName (string) - The name of the API module to load.
    @return (table) - The loaded API module, or nil if the module could not be loaded.
    
    The function performs the following steps:
    1. Checks if the API module is already cached and returns it if available.
    2. Constructs the file path for the API module.
    3. Checks if the API file exists.
    4. Loads the API file and verifies it contains valid read or write functions.
    5. Wraps the read, write, setValue, and readValue functions with logging functionality.
    6. Caches the modified API module and returns it.
    
    Logs errors if the API file is not found or does not contain valid functions.
]]
local function loadAPI(apiName)
    -- Return cached version if already loaded
    if apiCache[apiName] then return apiCache[apiName] end

    local apiFilePath = api_path .. apiName .. ".lua"

    -- Check if file exists before trying to load it
    if rfsuite.utils.file_exists(apiFilePath) then
        local apiModule = dofile(apiFilePath) -- Load the Lua API file

        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then

            -- Store the API name inside the module
            apiModule.__apiName = apiName

            -- Wrap the read function
            if apiModule.read then
                local originalRead = apiModule.read
                apiModule.read = function(...)
                    if rfsuite.config.logMSP then
                        rfsuite.utils.log(apiName .. "->read()", "info")
                    end    
                    return originalRead(...)
                end
            end

            -- Wrap the write function
            if apiModule.write then
                local originalWrite = apiModule.write
                apiModule.write = function(...)
                    if rfsuite.config.logMSP then
                        rfsuite.utils.log(apiName .. "->write()", "info")
                    end    
                    return originalWrite(...)
                end
            end

            -- Wrap the setValue function
            if apiModule.setValue then
                local originalSetValue = apiModule.setValue
                apiModule.setValue = function(...)
                    rfsuite.utils.log(apiName .. "->setValue()", "debug")
                    return originalSetValue(...)
                end
            end

            -- Wrap the readValue function
            if apiModule.readValue then
                local originalReadValue = apiModule.readValue
                apiModule.readValue = function(...)
                    rfsuite.utils.log(apiName .. "->readValue()", "debug")
                    return originalReadValue(...)
                end
            end



            -- Store the modified API in the cache
            apiCache[apiName] = apiModule
            rfsuite.utils.log("Loaded API: " .. apiName, "debug")
            return apiModule
        else
            rfsuite.utils.log("Error: API file '" .. apiName .. "' does not contain valid read or write functions.", "debug")
        end
    else
        rfsuite.utils.log("Error: API file '" .. apiFilePath .. "' not found.", "debug")
    end
end



--[[
    Loads the specified API by name.
    
    @param apiName (string) - The name of the API to load.
    @return (table) - The loaded API table, or nil if the API could not be loaded.
]]
function apiLoader.load(apiName)
    local api = loadAPI(apiName)
    if api == nil then
        rfsuite.utils.log("Unable to load " .. apiName,"debug")
    end
    return api
end

--[[
    Returns the size in bytes of the given data type.
    
    @param data_type (string): The data type to get the size of. 
                               Valid types are "U8", "U16", "U24", "U32", "S8", "S16", "S24", "S32".
    
    @return (number): The size in bytes of the given data type. Defaults to 1 if the data type is unknown.
]]
local function get_type_size(data_type)
    local type_sizes = {U8 = 1, U16 = 2, U24 = 3, U32 = 4, S8 = 1, S16 = 2, S24 = 3, S32 = 4}
    return type_sizes[data_type] or 1 -- Default to U8 if unknown
end


--[[
Parses MSP data from a buffer according to a given structure.

@param buf (string) The buffer containing the MSP data.
@param structure (table) The structure defining the data types and fields.
@param processed (table) Optional table to include in the returned data.
@param other (table) Optional table to include in the returned data.

@return (table) A table containing:
    - parsed: The parsed data as per the structure.
    - buffer: The original buffer.
    - structure: The original structure.
    - positionmap: A map of field names to their byte positions.
    - processed: The processed table if supplied.
    - other: The other table if supplied.
--]]
function apiLoader.parseMSPData(buf, structure, processed, other)

    -- Calculate the expected buffer length based on the structure
    local expected_length = 0
    for _, field in ipairs(structure) do
        expected_length = expected_length + get_type_size(field.type)
    end

    -- Ensure buffer length matches expected data structure
    if #buf < expected_length then
        rfsuite.utils.log("Error: Buffer too small. Expected " .. expected_length .. ", got " .. #buf,"debug")
    end
    
    local parsedData = {}
    local offset = 1 -- Maintain a strict offset tracking

    -- map of values to byte positions
    -- Function to build position map considering type sizes
    local function build_position_map(param_table)
        local position_map = {}
        local current_byte = 1 -- Track the byte position dynamically

        for _, param in ipairs(param_table) do
            -- Check API version conditions
            local apiVersion = rfsuite.session.apiVersion or 12.06
            local insert_param = false

            if not param.apiVersion or apiVersion >= param.apiVersion then
                insert_param = true
            else
                insert_param = false
            end

            if insert_param then
                local size = get_type_size(param.type)
                local start_pos = current_byte
                local end_pos = start_pos + size - 1
                local byteorder = param.byteorder or "little" -- Default to little-endian

                -- Store as single number if start and end are the same
                if start_pos == end_pos then
                    position_map[param.field] = {start_pos}
                else
                    position_map[param.field] = {}
                    if byteorder == "big" then
                        for i = end_pos, start_pos, -1 do
                            table.insert(position_map[param.field], i)
                        end
                    else
                        for i = start_pos, end_pos do
                            table.insert(position_map[param.field], i)
                        end
                    end
                end

                -- Move to the next available byte position
                current_byte = end_pos + 1

            end
        end

        return position_map
    end

    for _, field in ipairs(structure) do
        local byteorder = field.byteorder or "little" -- Default to little-endian
        local data

        if field.type == "U8" then
            data = rfsuite.tasks.msp.mspHelper.readU8(buf)
            offset = offset + 1 
        elseif field.type == "S8" then
            data = rfsuite.tasks.msp.mspHelper.readS8(buf)
            offset = offset + 1
        elseif field.type == "U16" then
            data = rfsuite.tasks.msp.mspHelper.readU16(buf, byteorder)
            offset = offset + 2
        elseif field.type == "S16" then
            data = rfsuite.tasks.msp.mspHelper.readS16(buf, byteorder)
            offset = offset + 2
        elseif field.type == "U24" then
            data = rfsuite.tasks.msp.mspHelper.readU24(buf, byteorder)
            offset = offset + 3
        elseif field.type == "S24" then
            data = rfsuite.tasks.msp.mspHelper.readS24(buf, byteorder)
            offset = offset + 3
        elseif field.type == "U32" then
            data = rfsuite.tasks.msp.mspHelper.readU32(buf, byteorder)
            offset = offset + 4
        elseif field.type == "S32" then
            data = rfsuite.tasks.msp.mspHelper.readS32(buf, byteorder)
            offset = offset + 4
        else
            rfsuite.utils.log("Error: Unknown data type: " .. field.type,"debug")
            return nil -- Exit if unknown data type
        end

        if data == nil then
            rfsuite.utils.log("Error " .. field.type .. " field: " .. field.field .. " offset: " .. offset,"debug")
        end   
        parsedData[field.field] = data

    end

    -- Check for unused bytes in the buffer
    if offset <= #buf then
        local extra_bytes = #buf - (offset - 1)
        rfsuite.utils.log("Unused bytes in buffer (" .. extra_bytes .. " extra bytes)")
    elseif offset > #buf + 1 then
        rfsuite.utils.log("Offset exceeded buffer length (Offset: " .. offset .. ", Buffer: " .. #buf .. ")")
    end

    -- Prepare data for return
    local data = {}
    data['parsed'] = parsedData
    data['buffer'] = buf
    data['structure'] = structure
    data['positionmap'] = build_position_map(structure)
    -- Add in processed table if supplied
    if processed then data['processed'] = processed end
    -- Add in other table if supplied
    if other then data['other'] = other end

    return data
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

    local apiVersion = rfsuite.session.apiVersion
    local totalBytes = 0

    for _, param in ipairs(structure) do
        local insert_param = false
    
        -- API version check logic
        if not param.apiVersion or (apiVersion and apiVersion >= param.apiVersion) then
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

    local apiVersion = rfsuite.session.apiVersion or 12.06
    local filteredStructure = {}

    for _, param in ipairs(structure) do
        local insert_param = false

        -- API version check logic
        if not param.apiVersion or (apiVersion and rfsuite.utils.round(apiVersion,2) >= rfsuite.utils.round(param.apiVersion,2)) then
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

    -- Attempt to load saved byte stream
    local byteStream, err = rfsuite.utils.simMspLoad(apiName)

    if byteStream and apiLoader.validateLoadedStream(byteStream, dataStructure) then
        return byteStream
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

-- This function checks that the loaded stream:
-- 1. Is a table
-- 2. Is at least 70% the length of the 'ideal' response built from dataStructure
function apiLoader.validateLoadedStream(byteStream, dataStructure)
    if type(byteStream) ~= "table" then
        return false
    end

    local expectedLength = 0
    for _, field in ipairs(dataStructure) do
        if field.simResponse then
            expectedLength = expectedLength + #field.simResponse
        else
            expectedLength = expectedLength + get_type_size(field.type)
        end
    end

    local minAcceptableLength = math.floor(expectedLength * 0.7)

    if #byteStream < minAcceptableLength then
        return false
    end

    return true
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
    Builds a write payload for the given API name and payload data based on the provided API structure.

    @param apiname (string) The name of the API.
    @param payload (table) The data to be serialized into the payload.
    @param api_structure (table) The structure defining the API fields and their types.

    @return (table) A byte stream representing the serialized payload.

    Internal Functions:
    - get_scale_from_page(field_name): Retrieves the scale factor for a given field name from the page data.
    - serialize_value(buf, value, data_type, byteorder): Serializes a value into the buffer based on its data type and byte order.

    Example Usage:
    local byte_stream = apiLoader.buildWritePayload("exampleAPI", {field1 = 10, field2 = 20}, api_structure)
]]
function apiLoader.buildWritePayload(apiname,payload, api_structure)

    local function get_scale_from_page(field_name)

        -- Quick exit if necessary data is not available
        if not rfsuite.app.Page.mspapi.api_reversed or not rfsuite.app.Page.fields then
            return 1
        end

        local page = rfsuite.app.Page.fields
        for i,v in ipairs(page) do
            if field_name == v.apikey and rfsuite.app.Page.mspapi.api_reversed[apiname] == v.mspapi then
                return v.scale
            end
        end
        return 1
    end

    local function serialize_value(buf, value, data_type, byteorder)

        if data_type == "U8" then
            rfsuite.tasks.msp.mspHelper.writeU8(buf, value)
        elseif data_type == "U16" then
            if byteorder then
                rfsuite.tasks.msp.mspHelper.writeU16(buf, value, byteorder)
            else
                rfsuite.tasks.msp.mspHelper.writeU16(buf, value)
            end
        elseif data_type == "U24" then
            if byteorder then
                rfsuite.tasks.msp.mspHelper.writeU24(buf, value, byteorder)
            else
                rfsuite.tasks.msp.mspHelper.writeU24(buf, value)
            end
        elseif data_type == "U32" then
            if byteorder then
                rfsuite.tasks.msp.mspHelper.writeU32(buf, value, byteorder)
            else
                rfsuite.tasks.msp.mspHelper.writeU32(buf, value)
            end            
        elseif data_type == "S8" then
            rfsuite.tasks.msp.mspHelper.writeS8(buf, value)
        elseif data_type == "S16" then
            if byteorder then
                rfsuite.tasks.msp.mspHelper.writeS16(buf, value, byteorder)
            else
                rfsuite.tasks.msp.mspHelper.writeS16(buf, value)
            end
        elseif data_type == "S24" then
            if byteorder then
                rfsuite.tasks.msp.mspHelper.writeS24(buf, value, byteorder)
            else
                rfsuite.tasks.msp.mspHelper.writeS24(buf, value)
            end
        elseif data_type == "S32" then
            if byteorder then
                rfsuite.tasks.msp.mspHelper.writeS32(buf, value, byteorder)
            else
                rfsuite.tasks.msp.mspHelper.writeS32(buf, value)
            end
        else
            error("Unknown type: " .. tostring(data_type))
        end
    end

    local byte_stream = {}

    for _, field_def in ipairs(api_structure) do
        local field_name = field_def.field
        local value = payload[field_name] or field_def.default or 0
        local byteorder = field_def.byteorder -- Only pass if defined
        local scale = field_def.scale or get_scale_from_page(field_name) or 1 -- Default scale to 1 if not defined

        value = math.floor(value * scale + 0.5)

        serialize_value(byte_stream, value, field_def.type, byteorder)
    end

    if rfsuite.config.logMSP then
        local logData = "Sending:  {" .. rfsuite.utils.joinTableItems(byte_stream, ", ") .. "}"
        rfsuite.utils.log(logData,"info")    
    end
    rfsuite.utils.simMspSave(apiname, byte_stream)   

    return byte_stream
end

return apiLoader
