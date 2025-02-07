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
local api_path = (rfsuite.utils.ethosVersionToMinor() >= 16) and apidir or (config.suiteDir .. apidir)

-- Function to load a specific API file by name and method
local function loadAPI(apiName)

    -- Return cached version if already loaded for this method
    if apiCache[apiName] then return apiCache[apiName] end

    local apiFilePath = api_path .. apiName .. ".lua"

    -- Check if file exists before trying to load it
    if rfsuite.utils.file_exists(apiFilePath) then

        -- we do this _G to pass a param via dofile.  A little dirty but effective.
        _G.paramMspApiPath = api_path .. apiName .. "/"
        local apiModule = dofile(apiFilePath) -- Load the Lua API file

        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then
            -- Store the loaded API in the cache
            apiCache[apiName] = apiModule
            rfsuite.utils.log("Loaded API:", apiName)
            if rfsuite.config.mspApiPositionMapDebug == true then
                print("--------------------------------------------")
                print("Loaded API:", apiName)
            end
            return apiModule
        else
            rfsuite.utils.log("Error: API file '" .. apiName .. "' does not contain valid read or write functions.")
        end
    else
        local logline = "Error: API file '" .. apiFilePath .. " not found."
        rfsuite.utils.log(logline)
        error(logline)
    end
end

-- Function to directly return the API table instead of a wrapper function
function apiLoader.load(apiName, method)
    return loadAPI(apiName, method) or {} -- Return an empty table if API fails to load
end

-- Function to parse the msp Data.  Optionally pass a processed(buf, structure) to provide more data formating
function apiLoader.parseMSPData(buf, structure, processed, other)
    -- Ensure buffer length matches expected data structure
    if #buf < #structure then return nil end

    local parsedData = {}
    local offset = 1 -- Maintain a strict offset tracking

    -- Function to get byte size from type
    local function get_type_size(data_type)
        local type_sizes = {U8 = 1, U16 = 2, U24 = 3, U32 = 4, S8 = 1, S16 = 2, S24 = 3, S32 = 4}
        return type_sizes[data_type] or 2 -- Default to U16 if unknown
    end

    -- map of values to byte positions
    -- Function to build position map considering type sizes
    local function build_position_map(param_table)
        local position_map = {}
        local current_byte = 1 -- Track the byte position dynamically

        if rfsuite.config.mspApiPositionMapDebug == true then print("------  mspApiPositionMapDebug start ------") end

        for _, param in ipairs(param_table) do
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
            if rfsuite.config.mspApiPositionMapDebug == true then
            if start_pos == end_pos then
                print(param.field .. ": " .. start_pos)
            else
                print(param.field .. ": " .. start_pos .. " to " .. end_pos)
            end
            end
        end

        if rfsuite.config.mspApiPositionMapDebug == true then
            print("------  mspApiPositionMapDebug end --------")
            print(" ")
        end

        return position_map
        end

    for _, field in ipairs(structure) do

        local byteorder = field.byteorder or "little" -- Default to little-endian

        if field.type == "U8" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU8(buf, offset)
            offset = offset + 1
        elseif field.type == "S8" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readS8(buf, offset)
            offset = offset + 1
        elseif field.type == "U16" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU16(buf, offset, byteorder)
            offset = offset + 2
        elseif field.type == "S16" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readS16(buf, offset, byteorder)
            offset = offset + 2
        elseif field.type == "U24" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU24(buf, offset, byteorder)
            offset = offset + 3
        elseif field.type == "S24" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readS24(buf, offset, byteorder)
            offset = offset + 3
        elseif field.type == "U32" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU32(buf, offset, byteorder)
            offset = offset + 4
        elseif field.type == "S32" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readS32(buf, offset, byteorder)
            offset = offset + 4
        else
            return nil -- Unknown data type, fail safely
        end
    end

    -- Detect unused bytes
    if offset <= #buf then
        rfsuite.utils.log("Warning: Unused bytes in buffer (" .. (#buf - offset + 1) .. " extra bytes)")
        print("Warning: Unused bytes in buffer (" .. (#buf - offset + 1) .. " extra bytes)")
    end

    -- prepare data for return
    local data = {}
    data['parsed'] = parsedData
    data['buffer'] = buf
    data['structure'] = structure
    data['positionmap'] = build_position_map(structure)
    -- add in processed table if supplied
    if processed then data['processed'] = processed end
    -- add in other table if supplied
    if other then data['other'] = other end

    if rfsuite.config.mspApiStructureDebug == true then rfsuite.utils.print_r(data['structure']) end

    if rfsuite.config.mspApiParsedDebug == true then rfsuite.utils.print_r(data['parsed']) end

    return data
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
