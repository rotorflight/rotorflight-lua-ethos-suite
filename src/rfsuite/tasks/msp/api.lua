--[[
  Copyright (C) 2025 Rotorflight Project
  GPLv3 — https://www.gnu.org/licenses/gpl-3.0.en.html
]] --

local rfsuite = require("rfsuite")

local apiLoader = {}

apiLoader._fileExistsCache = apiLoader._fileExistsCache or {}

apiLoader._apiCache = apiLoader._apiCache or {}
apiLoader._apiCacheOrder = apiLoader._apiCacheOrder or {}  
apiLoader._apiCacheMax = apiLoader._apiCacheMax or 10   


local apidir = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/tasks/msp/api/"
local api_path = apidir

local firstLoadAPI = true

local mspHelper
local utils
local callback

local function cached_file_exists(path)
    if apiLoader._fileExistsCache[path] == nil then apiLoader._fileExistsCache[path] = utils.file_exists(path) end
    return apiLoader._fileExistsCache[path]
end

local function loadAPI(apiName)

    local apiFilePath = api_path .. apiName .. ".lua"

    if firstLoadAPI then
        mspHelper = rfsuite.tasks.msp.mspHelper
        utils = rfsuite.utils
        callback = rfsuite.tasks.callback
        firstLoadAPI = false
    end

    if cached_file_exists(apiFilePath) then
        local apiModule = dofile(apiFilePath)

        if type(apiModule) == "table" and (apiModule.read or apiModule.write) then

            apiModule.__apiName = apiName

            if apiModule.read then
                local originalRead = apiModule.read
                apiModule.read = function(...) return originalRead(...) end
            end

            if apiModule.write then
                local originalWrite = apiModule.write
                apiModule.write = function(...) return originalWrite(...) end
            end

            if apiModule.setValue then
                local originalSetValue = apiModule.setValue
                apiModule.setValue = function(...) return originalSetValue(...) end
            end

            if apiModule.readValue then
                local originalReadValue = apiModule.readValue
                apiModule.readValue = function(...) return originalReadValue(...) end
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

function apiLoader.clearFileExistsCache() apiLoader._fileExistsCache = {} end

function apiLoader.load(apiName)
    local cached = apiLoader._apiCache[apiName]
    if cached then
        -- move this apiName to the end (MRU position)
        for i, name in ipairs(apiLoader._apiCacheOrder) do
            if name == apiName then
                table.remove(apiLoader._apiCacheOrder, i)
                break
            end
        end
        table.insert(apiLoader._apiCacheOrder, apiName)
        return cached
    end

    local api = loadAPI(apiName)
    if api == nil then
        utils.log("Unable to load " .. apiName, "debug")
        return nil
    end

    apiLoader._apiCache[apiName] = api
    table.insert(apiLoader._apiCacheOrder, apiName)

    if #apiLoader._apiCacheOrder > apiLoader._apiCacheMax then
        local oldest = table.remove(apiLoader._apiCacheOrder, 1)
        apiLoader._apiCache[oldest] = nil
    end

    return api
end

function apiLoader.resetApidata()

    if apiLoader.apidata.values then for i, v in pairs(apiLoader.apidata.values) do apiLoader.apidata.values[i] = nil end end

    if apiLoader.apidata.structure then for i, v in pairs(apiLoader.apidata.structure) do apiLoader.apidata.structure[i] = nil end end

    if apiLoader.apidata.receivedBytesCount then for i, v in pairs(apiLoader.apidata.receivedBytesCount) do apiLoader.apidata.receivedBytesCount[i] = nil end end

    if apiLoader.apidata.receivedBytes then for i, v in pairs(apiLoader.apidata.receivedBytes) do apiLoader.apidata.receivedBytes[i] = nil end end

    if apiLoader.apidata.positionmap then for i, v in pairs(apiLoader.apidata.positionmap) do apiLoader.apidata.positionmap[i] = nil end end

    if apiLoader.apidata.other then for i, v in pairs(apiLoader.apidata.other) do apiLoader.apidata.other[i] = nil end end

    apiLoader.apidata = {}

end

apiLoader.apidata = {}

return apiLoader
