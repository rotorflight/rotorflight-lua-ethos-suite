local render = {}

-- Object file cache
local objFileCache = {}

function render.object(boxType, x, y, w, h, box, telemetry)
    local baseDir = rfsuite.config.baseDir or "default"
    local objPath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/" .. boxType .. ".lua"

    -- Try to get the compiled object from the cache
    local obj = objFileCache[objPath]

    -- If not cached, load and compile it, then cache it
    if not obj then
        local ok, loaded = pcall(function()
            return assert(rfsuite.compiler.loadfile(objPath))()
        end)
        if not ok or type(loaded) ~= "table" then
            print("Failed to load object file for boxType: " .. tostring(boxType))
            return
        end
        obj = loaded
        objFileCache[objPath] = obj -- cache it
    end

    local func = obj[boxType]
    if type(func) ~= "function" then
        print("No function '" .. boxType .. "' in object file: " .. tostring(boxType))
        return
    end
    return func(x, y, w, h, box, telemetry)
end

return render
