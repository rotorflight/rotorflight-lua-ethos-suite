--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apiLoader = {}

-- Caches to avoid repeated disk checks and module loads
apiLoader._fileExistsCache = apiLoader._fileExistsCache or {}
apiLoader._apiCache        = apiLoader._apiCache or {}
apiLoader._apiCacheOrder   = apiLoader._apiCacheOrder or {} -- MRU list
apiLoader._apiCacheMax     = apiLoader._apiCacheMax or 10    -- Max cached modules

local apidir   = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api/"
local api_path = apidir

local firstLoadAPI = true -- Used to lazily bind helper references

local mspHelper
local utils
local callback

-- Cached file-exists wrapper
local function cached_file_exists(path)
    if apiLoader._fileExistsCache[path] == nil then
        apiLoader._fileExistsCache[path] = utils.file_exists(path)
    end
    return apiLoader._fileExistsCache[path]
end

-- Load an API module by name
local function loadAPI(apiName)

    local apiFilePath = api_path .. apiName .. ".lua"

    -- Lazy init of helpers on first module load
    if firstLoadAPI then
        mspHelper = rfsuite.tasks.msp.mspHelper
        utils     = rfsuite.utils
        callback  = rfsuite.tasks.callback
        firstLoadAPI = false
    end

    -- Check file before loading
    if cached_file_exists(apiFilePath) then
        local apiModule = dofile(apiFilePath)

        -- Valid API modules must expose read or write
        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then

            apiModule.__apiName = apiName

            -- Wrap read/write/setValue/readValue if present
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
            utils.log("Error: API file '" .. apiName .. "' missing read/write.", "debug")
        end
    else
        utils.log("Error: API file '" .. apiFilePath .. "' not found.", "debug")
    end
end

-- Clear cached file-exists checks
function apiLoader.clearFileExistsCache()
    apiLoader._fileExistsCache = {}
end

-- Load an API module with caching (LRU-like)
function apiLoader.load(apiName)
    local cached = apiLoader._apiCache[apiName]
    if cached then
        -- Move to MRU position
        for i, name in ipairs(apiLoader._apiCacheOrder) do
            if name == apiName then
                table.remove(apiLoader._apiCacheOrder, i)
                break
            end
        end
        table.insert(apiLoader._apiCacheOrder, apiName)
        return cached
    end

    -- Load from disk
    local api = loadAPI(apiName)
    if api == nil then
        utils.log("Unable to load " .. apiName, "debug")
        return nil
    end

    -- Add to cache
    apiLoader._apiCache[apiName] = api
    table.insert(apiLoader._apiCacheOrder, apiName)

    -- Enforce max cache size (drop oldest)
    if #apiLoader._apiCacheOrder > apiLoader._apiCacheMax then
        local oldest = table.remove(apiLoader._apiCacheOrder, 1)
        apiLoader._apiCache[oldest] = nil
    end

    return api
end

-- Reset stored API data fields
function apiLoader.resetApidata()
    if apiLoader.apidata.values then
        for i in pairs(apiLoader.apidata.values) do apiLoader.apidata.values[i] = nil end
    end

    if apiLoader.apidata.structure then
        for i in pairs(apiLoader.apidata.structure) do apiLoader.apidata.structure[i] = nil end
    end

    if apiLoader.apidata.receivedBytesCount then
        for i in pairs(apiLoader.apidata.receivedBytesCount) do apiLoader.apidata.receivedBytesCount[i] = nil end
    end

    if apiLoader.apidata.receivedBytes then
        for i in pairs(apiLoader.apidata.receivedBytes) do apiLoader.apidata.receivedBytes[i] = nil end
    end

    if apiLoader.apidata.positionmap then
        for i in pairs(apiLoader.apidata.positionmap) do apiLoader.apidata.positionmap[i] = nil end
    end

    if apiLoader.apidata.other then
        for i in pairs(apiLoader.apidata.other) do apiLoader.apidata.other[i] = nil end
    end

    apiLoader.apidata = {}
end

apiLoader.apidata = {}

return apiLoader
