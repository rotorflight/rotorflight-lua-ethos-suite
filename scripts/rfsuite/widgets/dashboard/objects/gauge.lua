local wrapper = {}

local renders = {}
local folder = "SCRIPTS:/" .. rfsuite.config.baseDir .. "/widgets/dashboard/objects/gauge/"

function wrapper.paint(x, y, w, h, box)
    local subtype = box.subtype or "bar"
    local render = renders[subtype]
    if not render then return end
    render.paint(x, y, w, h, box)
end

function wrapper.wakeup(box, telemetry)
    local subtype = box.subtype or "bar"

    if not renders[subtype] then
        local path = folder .. subtype .. ".lua"
        local loader = rfsuite.compiler.loadfile(path)
        if loader then
            renders[subtype] = loader()
        else
            return -- silently fail or log error
        end
    end

    local render = renders[subtype]
    render.wakeup(box, telemetry)
end

return wrapper
