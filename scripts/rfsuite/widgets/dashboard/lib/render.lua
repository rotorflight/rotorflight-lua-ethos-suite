local render = {}

function render.object(boxType, x, y, w, h, box, telemetry)
    local baseDir = rfsuite.config.baseDir or "default"
    local objPath = "SCRIPTS:/" .. baseDir .. "/widgets/dashboard/objects/" .. boxType .. ".lua"
    local ok, obj = pcall(function()
        return assert(rfsuite.compiler.loadfile(objPath))()
    end)
    if not ok or type(obj) ~= "table" then
        print("Failed to load object file for boxType: " .. tostring(boxType))
        return
    end
    local func = obj[boxType]
    if type(func) ~= "function" then
        print("No function '" .. boxType .. "' in object file: " .. tostring(boxType))
        return
    end
    return func(x, y, w, h, box, telemetry)
end

return render
