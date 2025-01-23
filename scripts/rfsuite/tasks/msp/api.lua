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
        
        if type(apiModule) == "table" and apiModule.get and apiModule.set and  apiModule.data and apiModule.isReady then
            apiCache[apiName] = apiModule  -- Store loaded API in cache
            rfsuite.utils.log("Loaded API:", apiName)
            return apiModule
        else
            rfsuite.utils.log("Error: API file '" .. apiName .. "' does not contain valid 'get' and 'set' functions.")
        end
    else
        rfsuite.utils.log("Error: API file '" .. apiName .. ".lua' not found.")
    end
end

-- Function to execute a given API, lazy-loading it when first called
function apiLoader.execute(apiName)
    return loadAPI(apiName)
end

-- Example usage
-- rfsuite.bg.msp.api.execute("myApi").get()        -- get function
-- rfsuite.bg.msp.api.execute("myApi").set()        -- set function
-- rfsuite.bg.msp.api.execute("myApi").isReady()    -- check if data is ready
-- rfsuite.bg.msp.api.execute("myApi").data(data)   -- return entire buffer

--
-- Note: The API name is the filename without the .lua extension
--      The variables callback and callbackParam are optional.
--      The callback function is called when the MSP response is received.
--      The data function is used to pass data to the API module.
--
-- Note: The API module must return a table with 'get', 'set' and 'data' functions. 
--
-- Note: The API module must have the following structure:
--      return { 
--          get = get,
--          set = set,
--          data = data,
--          isReady = isReady
--      }       
--
-- Note:  It is possible for individual API modules to have additional functions.
--        These functions can be called in the same way as 'get' and 'set'.
--        for example: 
--
--        rfsuite.bg.msp.api.execute("myApi").myFunction()
--         
--        It is up to you to read the api file and understand the functions it provides.
--
-- Example usage:
-- rfsuite.bg.msp.api.execute("MSP_MIXER_CONFIG").get()    -- do the msp call
-- if rfsuite.bg.msp.api.execute("MSP_MIXER_CONFIG").isReady() then
--    rfsuite.config.tailMode = rfsuite.bg.msp.api.execute("MSP_MIXER_CONFIG").getTailMode()
--    rfsuite.config.swashMode = rfsuite.bg.msp.api.execute("MSP_MIXER_CONFIG").getSwashMode()
--    rfsuite.utils.log("Tail mode: " .. rfsuite.config.tailMode)
--    rfsuite.utils.log("Swash mode: " .. rfsuite.config.swashMode)
    
--    print("Tail mode: " .. rfsuite.config.tailMode)
-- end    


return apiLoader
