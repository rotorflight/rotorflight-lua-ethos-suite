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


return apiLoader
