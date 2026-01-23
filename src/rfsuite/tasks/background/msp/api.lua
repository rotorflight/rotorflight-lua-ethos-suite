--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apiLoader = {}

-- Caches to avoid repeated disk checks and module loads
apiLoader._fileExistsCache = apiLoader._fileExistsCache or {}
apiLoader._chunkCache      = apiLoader._chunkCache or {}      -- apiName -> compiled loader function
apiLoader._chunkCacheOrder = apiLoader._chunkCacheOrder or {} -- MRU list (optional)
apiLoader._chunkCacheMax   = apiLoader._chunkCacheMax or 5    -- optional cap

local apidir   = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api/"
local api_path = apidir

local firstLoadAPI = true -- Used to lazily bind helper references

local mspHelper
local utils
local callback

-- Retrieve (and cache) compiled chunk for an API module
local function getChunk(apiName, apiFilePath)
    local chunk = apiLoader._chunkCache[apiName]
    if chunk then
        -- MRU touch (optional)
        for i, name in ipairs(apiLoader._chunkCacheOrder) do
            if name == apiName then table.remove(apiLoader._chunkCacheOrder, i); break end
        end
        table.insert(apiLoader._chunkCacheOrder, apiName)
        return chunk
    end

    -- Compile from disk once
    local loaderFn, err = loadfile(apiFilePath)
    if not loaderFn then
        utils.log("Error compiling API '" .. apiName .. "': " .. tostring(err), "debug")
        return nil
    end

    apiLoader._chunkCache[apiName] = loaderFn
    table.insert(apiLoader._chunkCacheOrder, apiName)

    -- Enforce max (optional)
    if #apiLoader._chunkCacheOrder > apiLoader._chunkCacheMax then
        local oldest = table.remove(apiLoader._chunkCacheOrder, 1)
        apiLoader._chunkCache[oldest] = nil
    end

    return loaderFn
end

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
        local chunk = getChunk(apiName, apiFilePath)
        if not chunk then return nil end

        local ok, apiModule = pcall(chunk)
        if not ok then
            utils.log("Error running API '" .. apiName .. "': " .. tostring(apiModule), "debug")
            return nil
        end

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

            if apiModule.setRebuildOnWrite then
                local original = apiModule.setRebuildOnWrite
                apiModule.setRebuildOnWrite = function(...) return original(...) end
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

-- Load an API module
function apiLoader.load(apiName)

    -- Load from disk
    local api = loadAPI(apiName)
    if api == nil then
        utils.log("Unable to load " .. apiName, "debug")
        return nil
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

-- Clear cached compiled chunks
function apiLoader.clearChunkCache()
    apiLoader._chunkCache = {}
    apiLoader._chunkCacheOrder = {}
end

apiLoader.apidata = {}

return apiLoader
