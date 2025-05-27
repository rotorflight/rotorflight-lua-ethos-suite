local render = {}
local objectCache = {} -- Add this table for caching

function render.object(boxType, x, y, w, h, box, telemetry)
    local baseDir = rfsuite.config.baseDir or "default"
    local objPath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/" .. boxType .. ".lua"

    -- Compose a unique cache key in case objPath can differ for same boxType
    local cacheKey = boxType

    -- Check the cache first
    local obj = objectCache[cacheKey]
    if not obj then
        local ok, loaded = pcall(function()
            return assert(rfsuite.compiler.loadfile(objPath))()
        end)
        if not ok or type(loaded) ~= "table" then
            rfsuite.utils.log("Failed to load object file for boxType: " .. tostring(boxType),"info")
            return
        end
        obj = loaded
        objectCache[cacheKey] = obj -- Cache it
    end

    local func = obj[boxType]
    if type(func) ~= "function" then
        rfsuite.utils.log("No function '" .. boxType .. "' in object file: " .. tostring(boxType),"info")
        return
    end
    return func(x, y, w, h, box, telemetry)
end

return render
