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

-- Function to load a specific API file by name
local function loadAPI(apiName)
    if apiCache[apiName] then
        return apiCache[apiName]  -- Return cached version if already loaded
    end

    local apiFilePath = api_path .. apiName .. ".lua"
    
    -- Check if file exists before trying to load it
    if rfsuite.utils.file_exists(apiFilePath) then

        local apiModule = dofile(apiFilePath)  -- Load the Lua API file
        
        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then
            apiCache[apiName] = apiModule  -- Store loaded API in cache
            rfsuite.utils.log("Loaded API:", apiName)
            return apiModule
        else
            rfsuite.utils.log("Error: API file '" .. apiName .. "' does not contain valid read or write functions.")
        end
    else
        rfsuite.utils.log("Error: API file '" .. apiName .. ".lua' not found.")
    end
end

-- Function to directly return the API table instead of a wrapper function
function apiLoader.load(apiName)
    return loadAPI(apiName) or {}  -- Return an empty table if API fails to load
end

function apiLoader.parseMSPData(buf, structure)
    -- Ensure buffer length matches expected data structure
    if #buf < #structure then
        return nil
    end

    local parsedData = {}
    local offset = 1  -- Maintain a strict offset tracking

    for _, field in ipairs(structure) do
        if field.type == "U8" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU8(buf, offset)
            offset = offset + 1
        elseif field.type == "U16" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU16(buf, offset)
            offset = offset + 2
        elseif field.type == "U24" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU24(buf, offset)
            offset = offset + 3
        elseif field.type == "U32" then
            parsedData[field.field] = rfsuite.bg.msp.mspHelper.readU32(buf, offset)
            offset = offset + 4
        else
            return nil  -- Unknown data type, fail safely
        end
    end

    -- prepare data for return
    local data = {}
    data['parsed'] = parsedData
    data['buffer'] = buf

    return data
end


return apiLoader
