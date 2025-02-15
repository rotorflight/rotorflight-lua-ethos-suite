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

-- Function to load a specific API file by name
local function loadAPI(apiName)

    -- Return cached version if already loaded
    if apiCache[apiName] then return apiCache[apiName] end

    local apiFilePath = api_path .. apiName .. ".lua"

    -- Check if file exists before trying to load it
    if rfsuite.utils.file_exists(apiFilePath) then

        local apiModule = dofile(apiFilePath) -- Load the Lua API file

        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then
            -- Store the loaded API in the cache
            apiCache[apiName] = apiModule
            rfsuite.utils.log("Loaded API:", apiName,"debug")
            return apiModule
        else
            rfsuite.utils.log("Error: API file '" .. apiName .. "' does not contain valid read or write functions.","debug")
        end
    else
        local logline = "Error: API file '" .. apiFilePath .. " not found."
        rfsuite.utils.log(logline,"debug")
    end
end

-- Function to directly return the API table instead of a wrapper function
function apiLoader.load(apiName)
    local api = loadAPI(apiName)
    if api == nil then
        rfsuite.utils.log("Unable to load " .. apiName,"debug")
    end
    return api
end


-- Function to get byte size from type
local function get_type_size(data_type)
    local type_sizes = {U8 = 1, U16 = 2, U24 = 3, U32 = 4, S8 = 1, S16 = 2, S24 = 3, S32 = 4}
    return type_sizes[data_type] or 1 -- Default to U8 if unknown
end


-- Function to parse the msp Data.  Optionally pass a processed(buf, structure) to provide more data formating
function apiLoader.parseMSPData(buf, structure, processed, other)
    -- Calculate the expected buffer length based on the structure
    
    local parsedData = {}
    local offset = 1 -- Maintain a strict offset tracking

    -- map of values to byte positions
    -- Function to build position map considering type sizes
    local function build_position_map(param_table)
        local position_map = {}
        local current_byte = 1 -- Track the byte position dynamically

        for _, param in ipairs(param_table) do
            -- Check API version conditions
            local apiVersion = rfsuite.config.apiVersion or 12.06
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
            data = rfsuite.bg.msp.mspHelper.readU8(buf, offset)
            offset = offset + 1 
        elseif field.type == "S8" then
            data = rfsuite.bg.msp.mspHelper.readS8(buf, offset)
            offset = offset + 1
        elseif field.type == "U16" then
            data = rfsuite.bg.msp.mspHelper.readU16(buf, offset, byteorder)
            offset = offset + 2
        elseif field.type == "S16" then
            data = rfsuite.bg.msp.mspHelper.readS16(buf, offset, byteorder)
            offset = offset + 2
        elseif field.type == "U24" then
            data = rfsuite.bg.msp.mspHelper.readU24(buf, offset, byteorder)
            offset = offset + 3
        elseif field.type == "S24" then
            data = rfsuite.bg.msp.mspHelper.readS24(buf, offset, byteorder)
            offset = offset + 3
        elseif field.type == "U32" then
            data = rfsuite.bg.msp.mspHelper.readU32(buf, offset, byteorder)
            offset = offset + 4
        elseif field.type == "S32" then
            data = rfsuite.bg.msp.mspHelper.readS32(buf, offset, byteorder)
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


-- Function to calculate MIN_BYTES and filtered structure
function apiLoader.calculateMinBytes(structure)

    local apiVersion = rfsuite.config.apiVersion
    local totalBytes = 0

    for _, param in ipairs(structure) do
        local insert_param = false

        -- API version check logic
        if not param.apiVersion or (apiVersion and apiVersion >= param.apiVersion) then
            insert_param = true
        end

        if insert_param then
            totalBytes = totalBytes + get_type_size(param.type)
        end
    end

    -- Subtract 2 bytes to allow for overlap times when developnent is in progress
    -- essentialy this allows a margin in which dev fbl firmware can be tested
    totalBytes = totalBytes - 2

    return totalBytes
end

-- Function to strip filtered structure based on msp version
function apiLoader.filterByApiVersion(structure)

    local apiVersion = rfsuite.config.apiVersion or 12.06
    local filteredStructure = {}

    for _, param in ipairs(structure) do
        local insert_param = false

        -- API version check logic
        if not param.apiVersion or (apiVersion and apiVersion >= param.apiVersion) then
            insert_param = true
        end

        if insert_param then
            table.insert(filteredStructure, param)
        end
    end

    return filteredStructure
end

function apiLoader.buildSimResponse(dataStructure)

    if system:getVersion().simulation == false then
        return nil
    end

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

-- handlers.lua
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

return apiLoader
